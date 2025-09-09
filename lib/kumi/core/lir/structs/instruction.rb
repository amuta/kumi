# lib/kumi/core/lir/structs/instruction.rb
# Fields:
# - opcode, result_register, stamp, inputs, immediates, attributes, location
module Kumi
  module Core
    module LIR
      module Structs
        Instruction = Struct.new(
          :opcode, :result_register, :stamp, :inputs, :immediates, :attributes, :location,
          keyword_init: true
        ) do
          def produces? = !result_register.nil?

          def to_h
            h = { op: opcode }
            h[:result]     = result_register if result_register
            h[:stamp]      = stamp.to_h if stamp
            h[:inputs]     = inputs unless inputs.nil? || inputs.empty?
            h[:immediates] = immediates&.map { |x| x.respond_to?(:to_h) ? x.to_h : x } unless immediates.nil? || immediates.empty?
            h[:attrs]      = attributes unless attributes.nil? || attributes.empty?
            h[:loc] = { file: location.file, line: location.line, column: location.column } if location
            h
          end
        end
      end
    end
  end
end
