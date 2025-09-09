# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        class LIRValidationPass < PassBase
          LIR = Kumi::Core::LIR

          def run(_errors)
            ops_by_decl =
              get_state(:lir_optimized_ops_by_decl)

            ops_by_decl.each do |decl, payload|
              validate_local_defs!(Array(payload[:operations]), decl)
              validate_single_yield!(Array(payload[:operations]), decl)
            end

            state
          end

          private

          def validate_local_defs!(ops, decl_name)
            defs = Set.new
            loop_depth = 0

            ops.each_with_index do |ins, _idx|
              # 1) check all inputs are defined
              Array(ins.inputs).each do |r|
                next if r.nil?
                raise "use-before-def #{r} in #{decl_name}" unless defs.include?(r)
              end

              # 2) special handling per opcode
              case ins.opcode
              when :LoopStart
                # collection_register must be defined already (checked above)
                # define loop-introduced registers *here*
                el = ins.attributes&.[](:as_element)
                ix = ins.attributes&.[](:as_index)
                defs << el if el
                defs << ix if ix
                loop_depth += 1

              when :LoopEnd
                loop_depth -= 1
                raise "unbalanced LoopEnd in #{decl_name}" if loop_depth < 0

              when :DeclareAccumulator
                # no regs defined (symbolic name only)

              when :Yield
                # input already checked

              else
                # 3) normal producers: record their result register as defined
                defs << ins.result_register if ins.result_register
              end
            end

            raise "unbalanced loops (depth=#{loop_depth}) in #{decl_name}" unless loop_depth.zero?
          end

          def validate_single_yield!(ops, decl_name)
            yi = ops.index { _1.opcode == :Yield }
            raise "no Yield in #{decl_name}" unless yi

            # exactly one Yield
            raise "multiple Yields in #{decl_name}" if ops.each_with_index.any? { |ins, i| ins.opcode == :Yield && i != yi }

            # after Yield, only structural LoopEnd is allowed
            trailing = ops[(yi + 1)..] || []
            bad = trailing.reject { _1.opcode == :LoopEnd }
            raise "instructions after Yield in #{decl_name}" unless bad.empty?
          end
        end
      end
    end
  end
end
