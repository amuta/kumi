# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        module Codegen
          module Loop
            module Js
              class Emitter
                def initialize(registry)
                  @registry = registry
                  @out = []
                  @indent = 0
                end

                def emit(loop_module, schema_digest: nil)
                  reset!

                  loop_module.each_function do |fn|
                    emit_function(fn)
                  end

                  to_s
                end

                private

                def reset!
                  @out.clear
                  @indent = 0
                end

                def to_s = @out.join

                def emit_function(fn)
                  @reg_axes = build_axes_map(fn)
                  write "export function _#{fn.name}(input) {"
                  indented do
                    fn.entry_block.instructions.each do |instr|
                      line = emit_instruction(instr)
                      write line if line
                    end
                    write "return #{reg(fn.return_reg)};"
                  end
                  write "}\n"
                end

                def emit_instruction(instr)
                  case instr.opcode
                  when :constant
                    "let #{reg(instr.result)} = #{format_literal(instr.attributes[:value])};"
                  when :load_input
                    key = instr.attributes[:key]
                    "let #{reg(instr.result)} = input[\"#{key}\"];"
                  when :load_field
                    field = instr.attributes[:field]
                    obj = reg(instr.inputs.first)
                    if vector_axes?(axes_for(instr.inputs.first))
                      "let #{reg(instr.result)} = #{obj}.map(el => el[\"#{field}\"]);"
                    else
                      "let #{reg(instr.result)} = #{obj}[\"#{field}\"];"
                    end
                  when :kernel_call
                    fn_id = instr.attributes[:fn]
                    out_axes = axes_for(instr.result)
                    if vector_axes?(out_axes)
                      vector_kernel_call(instr, fn_id)
                    else
                      args = instr.inputs.map { reg(_1) }
                      "let #{reg(instr.result)} = #{kernel_expr(fn_id, args)};"
                    end
                  when :select
                    out_axes = axes_for(instr.result)
                    if vector_axes?(out_axes)
                      vector_select(instr)
                    else
                      cond, on_true, on_false = instr.inputs.map { reg(_1) }
                      "let #{reg(instr.result)} = #{cond} ? #{on_true} : #{on_false};"
                    end
                  when :make_object
                    keys = Array(instr.attributes[:keys])
                    values = instr.inputs.map { reg(_1) }
                    out_axes = axes_for(instr.result)
                    if vector_axes?(out_axes)
                      raise "Loop JS codegen does not yet support vector make_object"
                    end
                    "let #{reg(instr.result)} = #{format_object(keys, values)};"
                  when :reduce
                    reduce_expr = fold_inline_expr(instr)
                    "let #{reg(instr.result)} = #{reduce_expr};"
                  else
                    raise "Loop JS codegen does not support #{instr.opcode.inspect}"
                  end
                end

                def vector_kernel_call(instr, fn_id)
                  args = instr.inputs
                  arg_axes = args.map { axes_for(_1) }
                  array_indexes = arg_axes.each_index.select { |i| vector_axes?(arg_axes[i]) }
                  raise "Loop JS codegen only supports 1D vectors" if arg_axes.any? { |ax| ax.size > 1 }

                  if array_indexes.empty?
                    expr = kernel_expr(fn_id, args.map { reg(_1) })
                    return "let #{reg(instr.result)} = #{expr};"
                  end

                  if array_indexes.size == 1
                    arr_idx = array_indexes.first
                    arr_reg = reg(args[arr_idx])
                    var = "el"
                    expr_args = args.map.with_index do |arg, idx|
                      idx == arr_idx ? var : reg(arg)
                    end
                    expr = kernel_expr(fn_id, expr_args)
                    return "let #{reg(instr.result)} = #{arr_reg}.map(#{var} => #{expr});"
                  end

                  vars = array_indexes.map.with_index { |_idx, i| "v#{i}" }
                  array_regs = array_indexes.map { |idx| reg(args[idx]) }
                  expr_args = args.map.with_index do |_arg, idx|
                    pos = array_indexes.index(idx)
                    pos ? vars[pos] : reg(args[idx])
                  end
                  expr = kernel_expr(fn_id, expr_args)
                  "let #{reg(instr.result)} = #{array_regs.first}.map((_, i) => { const [#{vars.join(', ')}] = [#{array_regs.join(', ')}].map(arr => arr[i]); return #{expr}; });"
                end

                def vector_select(instr)
                  args = instr.inputs
                  arg_axes = args.map { axes_for(_1) }
                  array_indexes = arg_axes.each_index.select { |i| vector_axes?(arg_axes[i]) }
                  raise "Loop JS codegen only supports 1D vectors" if arg_axes.any? { |ax| ax.size > 1 }

                  if array_indexes.empty?
                    cond, on_true, on_false = args.map { reg(_1) }
                    return "let #{reg(instr.result)} = #{cond} ? #{on_true} : #{on_false};"
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
                    return "let #{reg(instr.result)} = #{array_regs.first}.map(#{vars.first} => #{expr});"
                  end

                  "let #{reg(instr.result)} = #{array_regs.first}.map((_, i) => { const [#{vars.join(', ')}] = [#{array_regs.join(', ')}].map(arr => arr[i]); return #{expr}; });"
                end

                def fold_inline_expr(instr)
                  fn_id = instr.attributes[:fn]
                  arg = reg(instr.inputs.first)
                  kernel = @registry.kernel_for(fn_id, target: :javascript)
                  inline = kernel.fold_inline
                  raise "Missing fold_inline for #{fn_id}" if inline.nil? || inline.strip.empty?

                  apply_inline(inline, [arg])
                end

                def kernel_expr(fn_id, args)
                  kernel = @registry.kernel_for(fn_id, target: :javascript)
                  inline = kernel.inline
                  raise "Missing inline kernel for #{fn_id}" if inline.nil? || inline.strip.empty?

                  apply_inline(inline, args)
                end

                def apply_inline(template, args)
                  expr = template.strip
                  expr = expr.sub(/^=\s*/, "")
                  args.each_with_index { |arg, idx| expr = expr.gsub("$#{idx}", arg) }
                  expr
                end

                def write(line)
                  @out << ("  " * @indent) << line << "\n"
                end

                def indented
                  @indent += 1
                  yield
                  @indent -= 1
                end

                def reg(sym)
                  return "null" unless sym

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
                    pairs = keys.zip(values).map { |k, v| "\"#{k}\": #{v}" }
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
