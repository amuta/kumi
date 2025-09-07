# lib/kumi/core/lir/validate.rb
# Program-level structural checks. Assigns loop ids if absent.
module Kumi
  module Core
    module LIR
      module Validate
        module_function

        def program!(instructions, ids: nil)
          ensure_opcodes!(instructions)
          definitions = {}
          loop_stack = []

          instructions.each_with_index do |instruction, i|
            if instruction.produces?
              raise Error, "missing stamp at #{i}" unless instruction.stamp.is_a?(Stamp)
              reg = instruction.result_register
              raise Error, "redefinition of #{reg} at #{i}" if definitions.key?(reg)
              definitions[reg] = i
            end

            case instruction.opcode
            when :LoopStart
              attrs = instruction.attributes || {}
              raise Error, "LoopStart missing :axis at #{i}" unless attrs[:axis]
              instruction.attributes[:id] ||= (ids || Ids.new).generate_loop_id
              loop_stack << instruction.attributes[:id]
            when :LoopEnd
              raise Error, "LoopEnd without LoopStart at #{i}" if loop_stack.empty?
              loop_stack.pop
            when :Select
              # Optionally enforce stamp unification if stamps are present
              # (Leave as a no-op if you unify earlier.)
            end
          end

          raise Error, "unclosed loops: #{loop_stack}" unless loop_stack.empty?
          true
        end

        def ensure_opcodes!(instructions)
          instructions.each_with_index do |ins, i|
            next if OPCODES.include?(ins.opcode)
            raise Error, "unknown opcode #{ins.opcode.inspect} at #{i}"
          end
        end
        private_class_method :ensure_opcodes!
      end
    end
  end
end