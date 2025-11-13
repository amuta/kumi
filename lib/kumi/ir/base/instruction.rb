# frozen_string_literal: true

require "set"

module Kumi
  module IR
    module Base
      module Effects
        NONE    = [].freeze
        CONTROL = :control
        STATE   = :state
        MEMORY  = :memory
        IO      = :io

        ALL = Set[CONTROL, STATE, MEMORY, IO].freeze
      end

      class Instruction
        attr_reader :opcode, :result, :inputs, :attributes, :metadata, :effects
        attr_reader :axes, :dtype

        def initialize(opcode:, result: nil, inputs: [], attributes: {}, metadata: {}, effects: Effects::NONE)
          @opcode     = opcode.to_sym
          @result     = result
          @inputs     = Array(inputs).freeze
          @attributes = attributes.freeze
          @metadata   = metadata.freeze
          @effects    = normalize_effects(effects)
          @axes       = metadata[:axes] || []
          @dtype      = metadata[:dtype]
        end

        def produces? = !@result.nil?

        def effectful?
          !@effects.empty?
        end

        def control_effect? = @effects.include?(Effects::CONTROL)
        def state_effect?   = @effects.include?(Effects::STATE)
        def memory_effect?  = @effects.include?(Effects::MEMORY)
        def io_effect?      = @effects.include?(Effects::IO)

        def with_metadata(extra)
          self.class.new(
            opcode: @opcode,
            result: @result,
            inputs: @inputs,
            attributes: @attributes,
            metadata: @metadata.merge(extra),
            effects: @effects
          )
        end

        def to_h
          {
            opcode:,
            result:,
            inputs:,
            attributes:,
            metadata:,
            effects: @effects.to_a
          }
        end

        def to_print_string(_printer = nil)
          parts = []
          parts << "%#{result} =" if result
          parts << opcode.to_s
          parts << format_inputs(inputs)
          parts << format_attributes(printer_attributes)
          parts << format_axes_dtype
          parts.compact.join(" ")
        end

        def printer_attributes
          attributes
        end

        def printer_axes = axes
        def printer_dtype = dtype

        private

        def normalize_effects(effects)
          Array(effects).each_with_object(Set.new) do |eff, acc|
            next if eff.nil?
            sym = eff.to_sym
            raise ArgumentError, "unknown effect #{eff.inspect}" unless Effects::ALL.include?(sym)
            acc << sym
          end.freeze
        end

        def format_inputs(inputs)
          return nil if inputs.nil? || inputs.empty?

          "(#{inputs.map { format_value(_1) }.join(', ')})"
        end

        def format_attributes(attrs)
          return nil if attrs.nil? || attrs.empty?

          "[#{attrs.map { |k, v| "#{k}=#{format_value(v)}" }.join(', ')}]"
        end

        def format_axes_dtype
          axes = printer_axes
          dtype = printer_dtype || "unknown"
          axes_part = axes&.any? ? "[#{axes.join(', ')}]" : "[]"
          "#{axes_part} -> #{format_value(dtype)}"
        end

        def format_value(value)
          return value.to_s if defined?(Kumi::Core::Types::Type) && value.is_a?(Kumi::Core::Types::Type)

          case value
          when Symbol
            ":#{value}"
          when Array
            "[#{value.map { format_value(_1) }.join(', ')}]"
          else
            value.inspect
          end
        end
      end
    end
  end
end
