# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        module Codegen
          module Loop
            module Js
              # Serializes LoopIR into JavaScript. Every opcode maps to a fixed
              # syntax shape; all semantic decisions were made by Loop::Lower.
              class Emitter
                def initialize(registry)
                  @registry = registry
                  @out = []
                  @indent = 0
                end

                def emit(loop_module, schema_digest: nil, streaming: false)
                  reset!

                  loop_module.each_function do |fn|
                    emit_function(fn)
                    emit_streaming_function(fn) if streaming
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
                  write "export function _#{fn.name}(input) {"
                  indented do
                    emit_instructions(fn)
                    write "return #{reg(fn.return_reg)};"
                  end
                  write "}\n"
                end

                def emit_streaming_function(fn)
                  write "export function _#{fn.name}_stream(input, target = {}) {"
                  indented do
                    return_array_reg = direct_return_array_reg(fn)
                    if return_array_reg
                      write "let __streamTarget = Array.isArray(target) ? target : target[\"#{fn.name}\"];"
                      write "if (!Array.isArray(__streamTarget)) {"
                      indented do
                        write "__streamTarget = [];"
                        write "if (target && typeof target === \"object\" && !Array.isArray(target)) target[\"#{fn.name}\"] = __streamTarget;"
                      end
                      write "} else {"
                      indented { write "__streamTarget.length = 0;" }
                      write "}"
                    end

                    emit_instructions(fn, stream_return_array_reg: return_array_reg)
                    write "if (target && typeof target === \"object\" && !Array.isArray(target)) target[\"#{fn.name}\"] = #{reg(fn.return_reg)};"
                    write "return #{reg(fn.return_reg)};"
                  end
                  write "}\n"
                end

                def emit_instructions(fn, stream_return_array_reg: nil)
                  fn.entry_block.instructions.each do |instr|
                    emit_instruction(instr, stream_return_array_reg: stream_return_array_reg)
                  end
                end

                def emit_instruction(instr, stream_return_array_reg: nil)
                  case instr.opcode
                  when :constant
                    write "let #{reg(instr.result)} = #{format_literal(instr.attributes[:value])};"
                  when :load_input
                    key = instr.attributes[:key]
                    write "let #{reg(instr.result)} = input[\"#{key}\"];"
                  when :load_field
                    field = instr.attributes[:field]
                    write "let #{reg(instr.result)} = #{reg(instr.inputs.first)}[\"#{field}\"];"
                  when :kernel_call
                    args = instr.inputs.map { reg(_1) }
                    write "let #{reg(instr.result)} = #{kernel_expr(instr.attributes[:fn], args)};"
                  when :select
                    cond, on_true, on_false = instr.inputs.map { reg(_1) }
                    write "let #{reg(instr.result)} = #{cond} ? #{on_true} : #{on_false};"
                  when :make_object
                    keys = Array(instr.attributes[:keys])
                    values = instr.inputs.map { reg(_1) }
                    write "let #{reg(instr.result)} = #{format_object(keys, values)};"
                  when :ref
                    write "let #{reg(instr.result)} = #{reg(instr.inputs.first)};"
                  when :loop_start
                    source = reg(instr.inputs.first)
                    elem = reg(instr.result)
                    idx = reg(instr.attributes[:index])
                    write "for (let #{idx} = 0; #{idx} < #{source}.length; #{idx}++) {"
                    @indent += 1
                    write "let #{elem} = #{source}[#{idx}];"
                  when :loop_end
                    @indent -= 1
                    write "}"
                  when :array_init
                    if stream_return_array_reg == instr.result
                      write "let #{reg(instr.result)} = __streamTarget;"
                    else
                      write "let #{reg(instr.result)} = [];"
                    end
                  when :array_push
                    write "#{reg(instr.inputs[0])}.push(#{reg(instr.inputs[1])});"
                  when :array_len
                    write "let #{reg(instr.result)} = #{reg(instr.inputs.first)}.length;"
                  when :index_read
                    write "let #{reg(instr.result)} = #{reg(instr.inputs[0])}[#{reg(instr.inputs[1])}];"
                  when :shift_read
                    emit_shift_read(instr)
                  when :shift_in_bounds
                    index, length = instr.inputs.map { reg(_1) }
                    out = reg(instr.result)
                    offset = instr.attributes[:offset]
                    write "let #{out}_j = #{index} - (#{offset});"
                    write "let #{out} = #{out}_j >= 0 && #{out}_j < #{length};"
                  when :acc_init
                    init = instr.attributes[:nil_init] ? "null" : format_literal(instr.attributes[:init])
                    write "let #{reg(instr.result)} = #{init};"
                  when :acc_step
                    emit_acc_step(instr)
                  when :acc_load
                    write "let #{reg(instr.result)} = #{reg(instr.inputs.first)};"
                  else
                    raise "Loop JS codegen does not support #{instr.opcode.inspect}"
                  end
                end

                def direct_return_array_reg(fn)
                  fn.entry_block.instructions.any? do |instr|
                    instr.opcode == :array_init && instr.result == fn.return_reg
                  end ? fn.return_reg : nil
                end

                def emit_shift_read(instr)
                  array, index, length = instr.inputs.map { reg(_1) }
                  out = reg(instr.result)
                  offset = instr.attributes[:offset]

                  case instr.attributes[:policy]
                  when :wrap
                    write "let #{out} = #{array}[(((#{index} - (#{offset})) % #{length}) + #{length}) % #{length}];"
                  when :clamp
                    write "let #{out} = #{array}[Math.min(Math.max(#{index} - (#{offset}), 0), #{length} - 1)];"
                  else
                    raise "Loop JS codegen does not support shift policy #{instr.attributes[:policy].inspect}"
                  end
                end

                def emit_acc_step(instr)
                  acc = reg(instr.inputs[0])
                  value = reg(instr.inputs[1])
                  kernel = @registry.kernel_for(instr.attributes[:fn], target: :javascript)
                  template = kernel.inline
                  raise "Missing inline for #{instr.attributes[:fn]}" if template.nil? || template.strip.empty?

                  step = template.strip.gsub("$0", acc).gsub("$1", value)
                  write "#{acc} #{step};"
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

                def format_literal(value)
                  case value
                  when nil then "null"
                  when Symbol then value.to_s.inspect
                  else value.inspect
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
