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

              def_delegators :@buffer, :write, :indent!, :dedent!

              LIR = Kumi::Core::LIR

              def initialize(buffer, binds, kernels)
                @buffer = buffer
                @binds = binds
                @kernels = kernels
                @stack = []
                @out_containers = []
              end

              def emit(name, ops)
                @result_depth = calculate_result_depth(ops)

                write "def _eval_#{name}"
                indent!
                write @result_depth.zero? ? "out = nil" : "out = []"
                @out_containers = ["out"]
                ops.each { |ins| emit_ins(ins) }
                write "out"
                dedent!
                write "end\n"
              end

              private

              def emit_ins(ins)
                send("emit_#{ins.opcode.to_s.downcase}", ins)
              rescue NoMethodError
                write "# unsupported: #{ins.opcode}"
              end

              # ... other emit_* methods are unchanged ...

              def emit_loopstart(ins)
                coll = areg(ins.inputs.first)
                el = to_local(ins.attributes[:as_element])
                ix = to_local(ins.attributes[:as_index])

                write "#{coll}.each_with_index do |#{el}, #{ix}|"
                indent! # Increase indentation for the loop body

                @stack.push({ el: el, ix: ix })
                return unless @stack.length < @result_depth

                container = "out_#{@stack.length}"
                @out_containers.push(container)
                write "#{container} = []"
              end

              def emit_loopend(_ins)
                if @stack.length < @result_depth
                  child = @out_containers.pop
                  parent = @out_containers.last
                  write "#{parent} << #{child}"
                end
                @stack.pop

                dedent! # Decrease indentation before closing the block
                write "end"
              end

              # --- Unchanged emit methods ---
              def emit_kernelcall(ins)
                bind = @binds.fetch(ins.result_register)
                fn_name = kernel_method_name(bind.fn_id)
                args = Array(ins.inputs).map { areg(_1) }.join(", ")
                write "#{vreg(ins)} = #{fn_name}(#{args})"
              end

              def emit_accumulate(ins)
                bind = @binds.fetch(ins.result_register)
                fn_name = kernel_method_name(bind.fn_id)
                acc = ins.result_register
                v = areg(ins.inputs.first)
                write "#{acc} = #{fn_name}(#{acc}, #{v})"
              end

              def emit_constant(ins)
                write "#{vreg(ins)} = #{lit(ins.immediates.first)}"
              end

              def emit_loadinput(ins)
                write "#{vreg(ins)} = @input[#{imm_key(ins).inspect}]"
              end

              def emit_loadfield(ins)
                obj = areg(ins.inputs.first)
                key = imm_key(ins)
                write "#{vreg(ins)} = #{obj}[#{key.inspect}]"
              end

              def emit_select(ins)
                c, t, f = ins.inputs.map { areg(_1) }
                write "#{vreg(ins)} = (#{c}) ? (#{t}) : (#{f})"
              end

              def emit_declareaccumulator(ins)
                write "#{vreg(ins)} = #{lit(ins.immediates.first)}"
              end

              def emit_loadaccumulator(ins)
                acc_reg = ins.inputs.first or raise "No accumulator bound"
                write "#{vreg(ins)} = #{acc_reg}"
              end

              def emit_loaddeclaration(ins)
                write "#{vreg(ins)} = _eval_#{ins.immediates.first.value}"
              end

              def emit_yield(ins)
                v = areg(ins.inputs.first)
                if @result_depth.zero?
                  write "out = #{v}"
                else
                  write "#{@out_containers.last} << #{v}"
                end
              end

              def emit_maketuple(ins)
                elements = Array(ins.inputs).map { areg(_1) }.join(", ")
                write "#{vreg(ins)} = [#{elements}]"
              end

              # ---- Helpers ----
              def lit(l)
                v = l.value
                v.is_a?(Symbol) ? v.inspect : v.inspect
              end

              def imm_key(ins) = ins.immediates&.first&.value
              def to_local(sym) = sym.to_s.delete("%")
              def areg(r) = r.nil? ? "nil" : to_local(r)
              def vreg(ins) = to_local(ins.result_register)
              def kernel_method_name(fn_id) = "__#{fn_id.tr('.', '_')}"

              def calculate_result_depth(ops)
                ops.each.inject(0) do |depth, ins|
                  case ins.opcode
                  when :LoopStart then depth + 1
                  when :LoopEnd   then depth - 1
                  when :Yield     then return depth
                  else depth
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
