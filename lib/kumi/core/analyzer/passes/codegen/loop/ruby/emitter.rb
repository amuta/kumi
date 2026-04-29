# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        module Codegen
          module Loop
            module Ruby
              class Emitter
                def initialize(registry)
                  @registry = registry
                  @buffer = Codegen::Ruby::OutputBuffer.new
                  @helper_kernels = []
                end

                def emit(loop_module, schema_digest:)
                  @buffer.reset!
                  @buffer.emit_header(schema_digest)

                  loop_module.each_function do |fn|
                    emit_function(fn)
                  end

                  emit_helpers
                  @buffer.emit_footer
                  @buffer.to_s
                end

                private

                def emit_function(fn)
                  @reg_axes = build_axes_map(fn)
                  @buffer.write "def self._#{fn.name}(input)"
                  @buffer.indented do
                    fn.entry_block.instructions.each do |instr|
                      line = emit_instruction(instr)
                      @buffer.write(line) if line
                    end
                    @buffer.write "return #{reg(fn.return_reg)}"
                  end
                  @buffer.write "end\n"
                end

                def emit_instruction(instr)
                  case instr.opcode
                  when :constant
                    "#{reg(instr.result)} = #{format_literal(instr.attributes[:value])}"
                  when :load_input
                    key = instr.attributes[:key]
                    "#{reg(instr.result)} = input[\"#{key}\"] || input[:#{key}]"
                  when :load_field
                    field = instr.attributes[:field]
                    obj = reg(instr.inputs.first)
                    if vector_axes?(axes_for(instr.inputs.first))
                      "#{reg(instr.result)} = #{obj}.map { |el| el[\"#{field}\"] || el[:#{field}] }"
                    else
                      "#{reg(instr.result)} = #{obj}[\"#{field}\"] || #{obj}[:#{field}]"
                    end
                  when :kernel_call
                    fn_id = instr.attributes[:fn]
                    args = instr.inputs.map { reg(_1) }
                    out_axes = axes_for(instr.result)
                    if vector_axes?(out_axes)
                      vector_kernel_call(instr, fn_id)
                    else
                      "#{reg(instr.result)} = #{kernel_expr(fn_id, args)}"
                    end
                  when :select
                    out_axes = axes_for(instr.result)
                    if vector_axes?(out_axes)
                      vector_select(instr)
                    else
                      cond, on_true, on_false = instr.inputs.map { reg(_1) }
                      "#{reg(instr.result)} = #{cond} ? #{on_true} : #{on_false}"
                    end
                  when :make_object
                    keys = Array(instr.attributes[:keys])
                    values = instr.inputs.map { reg(_1) }
                    out_axes = axes_for(instr.result)
                    if vector_axes?(out_axes)
                      raise "Loop Ruby codegen does not yet support vector make_object"
                    end
                    "#{reg(instr.result)} = #{format_object(keys, values)}"
                  when :reduce
                    reduce_expr = fold_inline_expr(instr)
                    "#{reg(instr.result)} = #{reduce_expr}"
                  else
                    raise "Loop Ruby codegen does not support #{instr.opcode.inspect}"
                  end
                end

                def vector_kernel_call(instr, fn_id)
                  args = instr.inputs
                  arg_axes = args.map { axes_for(_1) }
                  array_indexes = arg_axes.each_index.select { |i| vector_axes?(arg_axes[i]) }
                  raise "Loop Ruby codegen only supports 1D vectors" if arg_axes.any? { |ax| ax.size > 1 }

                  if array_indexes.empty?
                    expr = kernel_expr(fn_id, args.map { reg(_1) })
                    return "#{reg(instr.result)} = #{expr}"
                  end

                  if array_indexes.size == 1
                    arr_idx = array_indexes.first
                    arr_reg = reg(args[arr_idx])
                    var = "el"
                    expr_args = args.map.with_index do |arg, idx|
                      idx == arr_idx ? var : reg(arg)
                    end
                    expr = kernel_expr(fn_id, expr_args)
                    return "#{reg(instr.result)} = #{arr_reg}.map { |#{var}| #{expr} }"
                  end

                  vars = array_indexes.map.with_index { |_idx, i| "v#{i}" }
                  array_regs = array_indexes.map { |idx| reg(args[idx]) }
                  expr_args = args.map.with_index do |_arg, idx|
                    pos = array_indexes.index(idx)
                    pos ? vars[pos] : reg(args[idx])
                  end
                  expr = kernel_expr(fn_id, expr_args)
                  zip_args = array_regs[1..].join(", ")
                  "#{reg(instr.result)} = #{array_regs.first}.zip(#{zip_args}).map { |#{vars.join(', ')}| #{expr} }"
                end

                def vector_select(instr)
                  args = instr.inputs
                  arg_axes = args.map { axes_for(_1) }
                  array_indexes = arg_axes.each_index.select { |i| vector_axes?(arg_axes[i]) }
                  raise "Loop Ruby codegen only supports 1D vectors" if arg_axes.any? { |ax| ax.size > 1 }

                  if array_indexes.empty?
                    cond, on_true, on_false = args.map { reg(_1) }
                    return "#{reg(instr.result)} = #{cond} ? #{on_true} : #{on_false}"
                  end

                  vars = array_indexes.map.with_index { |_idx, i| "v#{i}" }
                  array_regs = array_indexes.map { |idx| reg(args[idx]) }
                  expr_args = args.map.with_index do |_arg, idx|
                    pos = array_indexes.index(idx)
                    pos ? vars[pos] : reg(args[idx])
                  end
                  cond, on_true, on_false = expr_args
                  expr = "#{cond} ? #{on_true} : #{on_false}"

                  if array_regs.size == 1
                    return "#{reg(instr.result)} = #{array_regs.first}.map { |#{vars.first}| #{expr} }"
                  end

                  "#{reg(instr.result)} = #{array_regs.first}.zip(#{array_regs[1..].join(', ')}).map { |#{vars.join(', ')}| #{expr} }"
                end

                def fold_inline_expr(instr)
                  fn_id = instr.attributes[:fn]
                  arg = reg(instr.inputs.first)
                  kernel = @registry.kernel_for(fn_id, target: :ruby)
                  inline = kernel.fold_inline
                  raise "Missing fold_inline for #{fn_id}" if inline.nil? || inline.strip.empty?

                  apply_inline(inline, [arg])
                end

                def kernel_expr(fn_id, args)
                  kernel = @registry.kernel_for(fn_id, target: :ruby)
                  inline = kernel.inline
                  if inline && !inline.strip.empty?
                    return apply_inline(inline, args)
                  end

                  @helper_kernels << kernel
                  "#{kernel_method_name(kernel.fn_id)}(#{args.join(', ')})"
                end

                def apply_inline(template, args)
                  expr = template.strip
                  expr = expr.sub(/^=\s*/, "")
                  args.each_with_index { |arg, idx| expr = expr.gsub("$#{idx}", arg) }
                  expr
                end

                def emit_helpers
                  helpers = @helper_kernels.uniq { _1.id }
                  return if helpers.empty?

                  @buffer.section("private") do
                    helpers.each do |kernel|
                      next unless kernel.impl && !kernel.impl.strip.empty?

                      fn_name = kernel_method_name(kernel.fn_id)
                      impl_lines = kernel.impl.strip.split("\n", 2)
                      args = impl_lines.first.gsub(/[()]/, "").strip
                      body = impl_lines[1..].join("\n").strip

                      @buffer.write "def #{fn_name}(#{args})", 1
                      @buffer.write body, 2
                      @buffer.write "end\n", 1
                    end
                  end
                end

                def kernel_method_name(fn_id)
                  "__#{fn_id.tr('.', '_')}"
                end

                def reg(sym)
                  return "nil" unless sym

                  name = sym.to_s
                  return "t#{name[1..]}" if name.start_with?("v") && name[1..].to_i.to_s == name[1..]
                  name
                end

                def build_axes_map(fn)
                  map = {}
                  fn.entry_block.instructions.each do |instr|
                    map[instr.result] = Array(instr.axes) if instr.result
                  end
                  map
                end

                def axes_for(reg_name)
                  Array(@reg_axes[reg_name])
                end

                def vector_axes?(axes)
                  axes && !axes.empty?
                end

                def format_literal(value)
                  case value
                  when String
                    value.inspect
                  when Symbol
                    value.inspect
                  else
                    value.inspect
                  end
                end

                def format_object(keys, values)
                  return "[]" if keys.empty?

                  if tuple_keys?(keys)
                    "[#{values.join(', ')}]"
                  else
                    pairs = keys.zip(values).map { |k, v| "\"#{k}\" => #{v}" }
                    "{ #{pairs.join(', ')} }"
                  end
                end

                def tuple_keys?(keys)
                  return false if keys.empty?

                  keys = keys.map(&:to_s)
                  return false unless keys.all? { |k| k.match?(/^_\d+$/) }

                  expected = (0...keys.size).map { |i| "_#{i}" }
                  keys == expected
                end
              end
            end
          end
        end
      end
    end
  end
end
