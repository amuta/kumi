# frozen_string_literal: true

require "forwardable"

module Kumi
  module Core
    module Analyzer
      module Passes
        module Codegen
          module Ruby
            class DeclarationEmitter
              extend Forwardable

              def_delegators :@buffer, :write, :indent!, :dedent!, :last_line, :rewrite_line, :line_at

              LIR = Kumi::Core::LIR
              def initialize(buffer, binds, kernels)
                @buffer = buffer
                @binds = binds
                @kernels = kernels
                @stack = []
                @out_containers = []
              end

              def emit(name, ops)
                @ops = ops
                # Pre-calculate the depth of the single Yield instruction.
                @yield_depth = find_yield_depth(ops)

                write "def _#{name}"
                indent!

                # Setup the top-level 'out' container if the result is an array.
                write "out = []" if @yield_depth.positive?
                @out_containers = ["out"]

                # Simple, robust iteration.
                @ops.each_with_index { |ins, i| emit_ins(ins, i) }

                # Determine the final return value.
                if @ops.any? { _1.opcode == :Yield } && @yield_depth.zero?
                  # Scalar result is handled by emit_yield's optimization.
                else
                  write "out"
                end

                dedent!
                write "end\n"
              end

              private

              def emit_ins(ins, i)
                # Pass index `i` to loop handlers, others don't need it.
                if ins.opcode == :LoopStart
                  emit_loopstart(ins, i)
                elsif ins.opcode == :LoopEnd
                  emit_loopend(ins, i)
                elsif ins.opcode == :Yield
                  emit_yield(ins, i)
                else
                  # Dynamically call other emit_* methods without the index.
                  send("emit_#{ins.opcode.to_s.downcase}", ins, i)
                end
              end

              # --- SIMPLIFIED AND CORRECTED LOOP LOGIC ---

              def emit_loopstart(ins, i)
                coll = areg(ins.inputs.first)
                el = to_local(ins.attributes[:as_element])
                ix = to_local(ins.attributes[:as_index])

                write "#{coll}.each_with_index do |#{el}, _#{ix}|"
                indent!

                @stack.push({ el: el, ix: ix })

                # A loop needs a new sub-container if it contains a yield AND
                # its depth is less than the final yield's depth.
                return unless loop_contain_yield?(i) && @stack.length < @yield_depth

                container = "out_#{@stack.length}"
                @out_containers.push(container)
                write "#{container} = []"
              end

              def emit_loopend(ins, i)
                is_yield_container_loop = @stack.length < @yield_depth && loop_contain_yield?(find_loop_start_for_end(i))

                if is_yield_container_loop
                  child = @out_containers.pop
                  parent = @out_containers.last
                  write "#{parent} << #{child}"
                end

                @stack.pop
                dedent!
                write "end"
              end

              def emit_yield(ins, i)
                v = operands_for(ins)

                # Find the loop depth at the yield site.
                current_depth = 0
                @ops[0...i].each do |op|
                  current_depth += 1 if op.opcode == :LoopStart
                  current_depth -= 1 if op.opcode == :LoopEnd
                end

                if current_depth.zero?
                  if last_line.match?(/^#{v.first} = /)
                    new_end = last_line.sub("#{v.first} = ", "")
                    rewrite_line(new_end)
                  else
                    write v.first.to_s
                  end
                else
                  write "#{@out_containers.last} << #{v.first}"
                end
              end

              # ... other emit_* methods need to accept the index `i` ...
              # (The content of most of them doesn't change)
              def emit_kernelcall(ins, _i)
                kernel = kernel_for(ins.result_register)
                args = operands_for(ins)

                if (template = kernel[:attrs]["inline"])
                  inlined_code = _inline_kernel(template, args)
                  if template.start_with?("=") || template.include?("$0")
                    write "#{vreg(ins)} #{inlined_code}"
                  else
                    # For +=, -= etc.
                    write "#{vreg(ins)} #{inlined_code}".lstrip
                  end
                else
                  fn_name = kernel_method_name(kernel[:fn_id])
                  write "#{vreg(ins)} = #{fn_name}(#{args.join(', ')})"
                end
              end

              def emit_fold(ins, _i)
                kernel = kernel_for(ins.result_register)
                args = operands_for(ins)

                if (template = kernel[:attrs]["fold_inline"])
                  inlined_code = _inline_kernel(template, args)
                  write "#{vreg(ins)} #{inlined_code}"
                else
                  raise "Can't fold - no template defined"
                end
              end

              def emit_accumulate(ins, _i)
                kernel = kernel_for(ins.result_register)
                args = [vreg(ins), operands_for(ins).first]

                write "#{args[0]} ||= #{args[1]}" if kernel[:attrs]["first_element"]

                if (template = kernel[:attrs]["inline"])
                  inlined_code = _inline_kernel(template, args)
                  if template.include?("$0")
                    write "#{args[0]} #{inlined_code}"
                  else
                    write "#{args[0]} #{inlined_code}"
                  end
                else
                  fn_name = kernel_method_name(kernel[:fn_id])
                  write "#{args[0]} = #{fn_name}(#{args.join(', ')})"
                end
              end

              def emit_constant(ins, _i)
                write "#{vreg(ins)} = #{lit(ins.immediates.first)}"
              end

              def emit_loadinput(ins, _i)
                write "#{vreg(ins)} = @input[#{imm_key(ins).inspect}]"
              end

              def emit_loadfield(ins, _i)
                obj = areg(ins.inputs.first)
                key = imm_key(ins)
                write "#{vreg(ins)} = #{obj}[#{key.inspect}]"
              end

              def emit_select(ins, _i)
                c, t, f = operands_for(ins)
                write "#{vreg(ins)} = #{c} ? #{t} : #{f}"
              end

              def emit_declareaccumulator(ins, _i)
                kernel = kernel_for(ins.result_register)
                # Handling cases where identity might be a hash {integer: 0} or just 0
                identity_attrs = kernel[:attrs]["identity"]
                identity = identity_attrs.is_a?(Hash) ? identity_attrs["integer"] || identity_attrs["any"] : identity_attrs
                write "#{vreg(ins)} = #{identity.inspect}"
              end

              def emit_loadaccumulator(ins, _i)
                acc_reg = ins.inputs.first or raise "No accumulator bound"
                write "#{vreg(ins)} = #{acc_reg}"
              end

              def emit_loaddeclaration(ins, _i)
                write "#{vreg(ins)} = _#{ins.immediates.first.value}"
              end

              def emit_maketuple(ins, _i)
                elements = operands_for(ins).join(", ")
                write "#{vreg(ins)} = [#{elements}]"
              end

              def emit_makeobject(ins, _i)
                values, keys = operands_for(ins, split: true)
                write "#{vreg(ins)} = {"
                indent!
                keys.each_with_index do |key, idx|
                  write "#{key} => #{values[idx]},"
                end
                dedent!
                write "}"
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

              def find_yield_depth(ops)
                yield_op_index = ops.index { _1.opcode == :Yield }
                return 0 unless yield_op_index

                depth = 0
                ops[0...yield_op_index].each do |op|
                  depth += 1 if op.opcode == :LoopStart
                  depth -= 1 if op.opcode == :LoopEnd
                end
                depth
              end

              # --- Unchanged helpers ---
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

              def lit(l)
                v = l.value
                v.is_a?(Symbol) ? v.inspect : v.inspect
              end

              def imm_key(ins) = ins.immediates&.first&.value
              def to_local(sym) = sym.to_s.delete("%")
              def areg(r) = r.nil? ? "nil" : to_local(r)
              def vreg(ins) = to_local(ins.result_register)
              def kernel_method_name(fn_id) = "__#{fn_id.tr('.', '_')}"

              def kernel_for(reg)
                bind = @binds.fetch(reg)
                @kernels[bind.fn_id]
              end

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
