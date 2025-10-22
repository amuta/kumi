# frozen_string_literal: true

require "forwardable"
require "json"

module Kumi
  module Core
    module Analyzer
      module Passes
        module Codegen
          module Js
            class DeclarationEmitter
              extend Forwardable

              def_delegators :@buffer, :write, :indent!, :dedent!, :last_line, :rewrite_line

              def initialize(buffer, binds, kernels)
                @buffer = buffer
                @binds = binds
                @kernels = kernels
                @stack = []
                @out_containers = []
                @aliases = {}
              end

              def emit(name, ops)
                @ops = ops
                @yield_depth = find_yield_depth(ops)
                has_yield = @ops.any? { |op| op.opcode == :Yield }
                @aliases.clear

                # Exported, pure function per declaration
                write "export function _#{name}(input) {"
                indent!

                write "let out = [];" if has_yield && @yield_depth.positive?
                @out_containers = ["out"]

                @ops.each_with_index { |ins, i| emit_ins(ins, i) }

                write "return out;" if has_yield && @yield_depth.positive?

                dedent!
                write "}\n"
              end

              private

              def emit_ins(ins, i)
                emitter_method = "emit_#{ins.opcode.to_s.downcase}"
                if respond_to?(emitter_method, true)
                  send(emitter_method, ins, i)
                else
                  warn "No JS emitter found for opcode: #{ins.opcode}"
                end
              end

              # --- Loop and Yield Logic ---

              def emit_loopstart(ins, i)
                coll = areg(ins.inputs.first)
                el = to_local(ins.attributes[:as_element])
                ix = to_local(ins.attributes[:as_index])

                write "#{coll}.forEach((#{el}, #{ix}) => {"
                indent!
                @stack.push({ el: el, ix: ix })

                return unless loop_contain_yield?(i) && @stack.length < @yield_depth

                container = "out_#{@stack.length}"
                @out_containers.push(container)
                write "let #{container} = [];"
              end

              def emit_loopend(_ins, i)
                start_index = find_loop_start_for_end(i)
                is_yield_container_loop = @stack.length < @yield_depth && loop_contain_yield?(start_index)

                if is_yield_container_loop
                  child = @out_containers.pop
                  parent = @out_containers.last
                  write "#{parent}.push(#{child});"
                end

                @stack.pop
                dedent!
                write "});"
              end

              def emit_yield(ins, i)
                v = operands_for(ins).first
                current_depth = calculate_depth_at(i)

                if current_depth.zero?
                  # Optimization: if the last statement was the assignment,
                  # we can just make it a return statement.
                  if last_line&.strip&.match?(/^let #{v} = /)
                    new_line = last_line.sub("let #{v} = ", "return ")
                    rewrite_line(new_line.strip.chomp(";"))
                  else
                    write "return #{v};"
                  end
                else
                  write "#{@out_containers.last}.push(#{v});"
                end
              end

              def emit_kernelcall(ins, _i)
                kernel = kernel_for(ins.result_register)
                args = operands_for(ins)

                if (template = kernel[:attrs]["js_inline"] || kernel[:attrs]["inline"])
                  inlined_code = _inline_kernel(template, args)
                  if template.start_with?("=") || template.include?("$0")
                    write "let #{vreg(ins)} #{inlined_code};"
                  else
                    write "#{vreg(ins)} #{inlined_code};"
                  end
                else
                  fn_name = kernel_method_name(kernel[:fn_id])
                  write "let #{vreg(ins)} = #{fn_name}(#{args.join(', ')});"
                end
              end

              def emit_importschemacall(ins, _i)
                # Generate code to call an imported schema function
                source_module = ins.attributes[:source_module]
                fn_name = ins.attributes[:fn_name]
                input_keys = ins.attributes[:input_mapping_keys]
                args = operands_for(ins)

                js_module = ruby_module_to_js(source_module)
                input_obj = input_keys.zip(args).map { |k, v| "'#{k}': #{v}" }.join(", ")

                write "let #{vreg(ins)} = #{js_module}.from({#{input_obj}})._#{fn_name};"
              end

              private

              def ruby_module_to_js(ruby_module_path)
                # Convert Ruby module path (GoldenSchemas::Tax) to JavaScript path (GoldenSchemas.Tax)
                ruby_module_path.to_s.gsub('::', '.')
              end

              def emit_fold(ins, _i)
                kernel = kernel_for(ins.result_register)
                args = operands_for(ins)

                if (template = kernel[:attrs]["js_fold_inline"] || kernel[:attrs]["fold_inline"])
                  inlined_code = _inline_kernel(template, args)
                  write "let #{vreg(ins)} #{inlined_code};"
                else
                  raise "JS Emitter: Can't fold - no 'js_fold_inline' or 'fold_inline' template defined for kernel #{kernel[:fn_id]}"
                end
              end

              def emit_accumulate(ins, _i)
                kernel = kernel_for(ins.result_register)
                args = [vreg(ins), operands_for(ins).first]

                if kernel[:attrs]["first_element"]
                  write "if (#{args[0]} === null || #{args[0]} === undefined) {"
                  indent!
                  write "#{args[0]} = #{args[1]};"
                  dedent!
                  write "} else {"
                  indent!
                end

                if (template = kernel[:attrs]["js_inline"] || kernel[:attrs]["inline"])
                  inlined_code = _inline_kernel(template, args)
                  write "#{args[0]} #{inlined_code};"
                else
                  fn_name = kernel_method_name(kernel[:fn_id])
                  write "#{args[0]} = #{fn_name}(#{args.join(', ')});"
                end

                return unless kernel[:attrs]["first_element"]

                dedent!
                write "}"
              end

              def emit_constant(ins, _i)
                write "const #{vreg(ins)} = #{lit(ins.immediates.first)};"
              end

              def emit_loadinput(ins, _i)
                key = imm_key(ins)
                write "let #{vreg(ins)} = input[#{key.to_json}];"
              end

              def emit_loadfield(ins, _i)
                obj = areg(ins.inputs.first)
                key = imm_key(ins)

                write "let #{vreg(ins)} = #{obj}[#{key.to_json}];"
              end

              def emit_select(ins, _i)
                c, t, f = operands_for(ins)
                write "let #{vreg(ins)} = #{c} ? #{t} : #{f};"
              end

              def emit_declareaccumulator(ins, _i)
                kernel = kernel_for(ins.result_register)
                identity_attrs = kernel[:attrs]["identity"]
                identity = identity_attrs.is_a?(Hash) ? identity_attrs["integer"] || identity_attrs["any"] : identity_attrs
                write "let #{vreg(ins)} = #{identity.to_json};"
              end

              def emit_loadaccumulator(ins, _i)
                acc_reg = ins.inputs.first or raise "No accumulator bound"
                # This is a no-op for codegen; it creates an alias that `areg` will resolve.
                @aliases[vreg(ins)] = areg(acc_reg)
              end

              def emit_loaddeclaration(ins, _i)
                write "let #{vreg(ins)} = _$#{ins.immediates.first.value}(input);"
              end

              def emit_maketuple(ins, _i)
                elements = operands_for(ins).join(", ")
                write "let #{vreg(ins)} = [#{elements}];"
              end

              def emit_makeobject(ins, _i)
                values, keys = operands_for(ins, split: true)
                write "let #{vreg(ins)} = {"
                indent!
                keys.each_with_index do |key, idx|
                  postfix = idx == keys.size - 1 ? "" : ","
                  # Keys in JS objects from variables don't need quotes if they are valid identifiers
                  write "#{key}: #{values[idx]}#{postfix}"
                end
                dedent!
                write "};"
              end

              def emit_length(ins, _i)
                arr = ins.inputs[0]
                write "let #{vreg(ins)} = #{arr}.length;"
              end

              def emit_gather(ins, _)
                arr = ins.inputs[0]
                idx = ins.inputs[1]
                write "let #{vreg(ins)} = #{arr}[#{idx}];"
              end

              def find_matching_loop_end(start_index)
                depth = 1; (start_index + 1...@ops.length).each do |i|
                  op = @ops[i].opcode
                  depth += 1 if op == :LoopStart
                  depth -= 1 if op == :LoopEnd
                  return i if depth.zero?
                end
                raise "Unbalanced LoopStart at index #{start_index}"
              end

              def find_loop_start_for_end(end_index)
                depth = 1; (end_index - 1).downto(0) do |i|
                  op = @ops[i].opcode
                  depth += 1 if op == :LoopEnd
                  depth -= 1 if op == :LoopStart
                  return i if depth.zero?
                end
                raise "Unbalanced LoopEnd at index #{end_index}"
              end

              def loop_contain_yield?(loop_start_index)
                end_index = find_matching_loop_end(loop_start_index)
                @ops[(loop_start_index + 1)...end_index].any? { |ins| ins.opcode == :Yield }
              end

              def calculate_depth_at(index)
                depth = 0
                @ops[0...index].each do |op|
                  depth += 1 if op.opcode == :LoopStart
                  depth -= 1 if op.opcode == :LoopEnd
                end
                depth
              end

              def find_yield_depth(ops)
                yield_op_index = ops.index { _1.opcode == :Yield }
                return 0 unless yield_op_index

                calculate_depth_at(yield_op_index)
              end

              def operands_for(ins, split: false)
                immediates = Array(ins.immediates).map { |imm| lit(imm) }
                inputs = Array(ins.inputs).map do |input|
                  if input == :__immediate_placeholder__
                    immediates.shift
                  else
                    areg(input)
                  end
                end
                return [inputs, immediates] if split

                inputs + immediates
              end

              def lit(l) = l.value.to_json
              def imm_key(ins) = ins.immediates&.first&.value
              def to_local(sym) = sym.to_s.delete("%:")

              def areg(r)
                return "null" if r.nil?

                resolved = to_local(r)
                # Follow the alias chain to find the original source register.
                while (aliased_to = @aliases[resolved])
                  resolved = aliased_to
                end
                resolved
              end

              def vreg(ins) = to_local(ins.result_register)
              def kernel_method_name(fn_id) = "__#{fn_id.tr('.', '_')}"
              def kernel_for(reg) = @kernels.fetch(@binds.fetch(reg).fn_id)

              def _inline_kernel(template, args)
                inlined = template.dup
                args.each_with_index { |arg, i| inlined.gsub!("$#{i}", arg.to_s) }
                inlined
              end
            end
          end
        end
      end
    end
  end
end
