# lib/kumi/core/lir/validate.rb
# Per-declaration and program-level structural checks.
module Kumi
  module Core
    module LIR
      module Validate
        module_function

        # Validate one declaration's instruction list
        def declaration!(instructions)
          ensure_opcodes!(instructions)

          defs = {}
          depth = 0
          yield_seen = false

          instructions.each_with_index do |ins, i|
            # producer stamps
            if ins.result_register
              raise Error, "missing stamp at #{i}" unless ins.stamp.is_a?(Stamp)
              r = ins.result_register
              raise Error, "redefinition of #{r} at #{i}" if defs.key?(r)
              defs[r] = i
            end

            case ins.opcode
            when :LoopStart
              attrs = ins.attributes || {}
              raise Error, "LoopStart missing :axis at #{i}" unless attrs[:axis]
              depth += 1
            when :LoopEnd
              raise Error, "LoopEnd without LoopStart at #{i}" if depth.zero?
              depth -= 1
            when :LoadDeclaration
              raise Error, "LoadDeclaration missing :axes at #{i}" unless Array(ins.attributes[:axes]).is_a?(Array)
              raise Error, "LoadDeclaration missing stamp at #{i}" unless ins.stamp.is_a?(Stamp)
            when :Yield
              raise Error, "multiple Yield (at #{i})" if yield_seen
              yield_seen = true
              raise Error, "instructions after Yield (at #{i})" unless i == instructions.length - 1
            end
          end

          raise Error, "unclosed loops" unless depth.zero?
          raise Error, "missing Yield" unless yield_seen
          true
        end

        # Validate whole program: { name => { operations: [...] } }
        def program!(ops_by_decl)
          ops_by_decl.each do |name, h|
            declaration!(Array(h[:operations]))
          end
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