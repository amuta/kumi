# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        module Codegen
          module Loop
            module Ruby
              # Serializes LoopIR into Ruby. Every opcode maps to a fixed
              # syntax shape; all semantic decisions were made by Loop::Lower.
              class Emitter
                def initialize(registry)
                  @registry = registry
                  @buffer = OutputBuffer.new
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
                  @buffer.write "def self._#{fn.name}(input)"
                  @buffer.indented do
                    fn.entry_block.instructions.each do |instr|
                      emit_instruction(instr)
                    end
                    @buffer.write "return #{reg(fn.return_reg)}"
                  end
                  @buffer.write "end\n"
                end

                def emit_instruction(instr)
                  case instr.opcode
                  when :constant
                    @buffer.write "#{reg(instr.result)} = #{format_literal(instr.attributes[:value])}"
                  when :load_input
                    key = instr.attributes[:key]
                    @buffer.write "#{reg(instr.result)} = input[\"#{key}\"] || input[:#{key}]"
                  when :load_field
                    field = instr.attributes[:field]
                    obj = reg(instr.inputs.first)
                    @buffer.write "#{reg(instr.result)} = #{obj}[\"#{field}\"] || #{obj}[:#{field}]"
                  when :kernel_call
                    args = instr.inputs.map { reg(_1) }
                    @buffer.write "#{reg(instr.result)} = #{kernel_expr(instr.attributes[:fn], args)}"
                  when :select
                    cond, on_true, on_false = instr.inputs.map { reg(_1) }
                    @buffer.write "#{reg(instr.result)} = #{cond} ? #{on_true} : #{on_false}"
                  when :make_object
                    keys = Array(instr.attributes[:keys])
                    values = instr.inputs.map { reg(_1) }
                    @buffer.write "#{reg(instr.result)} = #{format_object(keys, values)}"
                  when :ref
                    @buffer.write "#{reg(instr.result)} = #{reg(instr.inputs.first)}"
                  when :loop_start
                    source = reg(instr.inputs.first)
                    elem = reg(instr.result)
                    idx = reg(instr.attributes[:index])
                    @buffer.write "#{source}.each_with_index do |#{elem}, #{idx}|"
                    @buffer.indent!
                  when :loop_end
                    @buffer.dedent!
                    @buffer.write "end"
                  when :array_init
                    @buffer.write "#{reg(instr.result)} = []"
                  when :array_push
                    @buffer.write "#{reg(instr.inputs[0])} << #{reg(instr.inputs[1])}"
                  when :array_len
                    @buffer.write "#{reg(instr.result)} = #{reg(instr.inputs.first)}.length"
                  when :index_read
                    @buffer.write "#{reg(instr.result)} = #{reg(instr.inputs[0])}[#{reg(instr.inputs[1])}]"
                  when :shift_read
                    emit_shift_read(instr)
                  when :shift_in_bounds
                    index, length = instr.inputs.map { reg(_1) }
                    out = reg(instr.result)
                    offset = instr.attributes[:offset]
                    @buffer.write "#{out}_j = #{index} - (#{offset})"
                    @buffer.write "#{out} = #{out}_j >= 0 && #{out}_j < #{length}"
                  when :acc_init
                    init = instr.attributes[:nil_init] ? "nil" : format_literal(instr.attributes[:init])
                    @buffer.write "#{reg(instr.result)} = #{init}"
                  when :acc_step
                    emit_acc_step(instr)
                  when :acc_load
                    @buffer.write "#{reg(instr.result)} = #{reg(instr.inputs.first)}"
                  else
                    raise "Loop Ruby codegen does not support #{instr.opcode.inspect}"
                  end
                end

                def emit_shift_read(instr)
                  array, index, length = instr.inputs.map { reg(_1) }
                  out = reg(instr.result)
                  offset = instr.attributes[:offset]

                  case instr.attributes[:policy]
                  when :wrap
                    @buffer.write "#{out} = #{array}[((#{index} - (#{offset})) % #{length} + #{length}) % #{length}]"
                  when :clamp
                    @buffer.write "#{out} = #{array}[(#{index} - (#{offset})).clamp(0, #{length} - 1)]"
                  else
                    raise "Loop Ruby codegen does not support shift policy #{instr.attributes[:policy].inspect}"
                  end
                end

                def emit_acc_step(instr)
                  acc = reg(instr.inputs[0])
                  value = reg(instr.inputs[1])
                  kernel = @registry.kernel_for(instr.attributes[:fn], target: :ruby)
                  template = kernel.inline
                  raise "Missing inline for #{instr.attributes[:fn]}" if template.nil? || template.strip.empty?

                  @buffer.write "#{acc} ||= #{value}" if instr.attributes[:nil_init]
                  step = template.strip.gsub("$0", acc).gsub("$1", value)
                  @buffer.write "#{acc} #{step}"
                end

                def kernel_expr(fn_id, args)
                  kernel = @registry.kernel_for(fn_id, target: :ruby)
                  inline = kernel.inline
                  return apply_inline(inline, args) if inline && !inline.strip.empty?

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

                def format_literal(value)
                  value.inspect
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
