# frozen_string_literal: true

require "json"

module Kumi::Core
  module JsonSchema
    # Converts Kumi schema metadata to JSON Schema format
    class Generator
      def initialize(schema_metadata)
        @metadata = schema_metadata
      end

      def generate
        {
          type: "object",
          properties: build_properties,
          required: extract_required_fields,
          "x-kumi-values": @metadata.values,
          "x-kumi-traits": @metadata.traits
        }
      end

      private

      def build_properties
        @metadata.inputs.transform_values { |spec| convert_input_to_json_schema(spec) }
      end

      def extract_required_fields
        @metadata.inputs.select { |_k, v| v[:required] }.keys
      end

      def convert_input_to_json_schema(input_spec)
        base = { type: map_kumi_type_to_json_schema(input_spec[:type]) }

        domain = input_spec[:domain]
        return base unless domain

        case domain[:type]
        when :range
          base[:minimum] = domain[:min]
          base[:maximum] = domain[:max]
        when :enum
          base[:enum] = domain[:values]
        end

        base
      end

      def map_kumi_type_to_json_schema(kumi_type)
        case kumi_type
        when :string then "string"
        when :integer then "integer"
        when :float then "number"
        when :boolean then "boolean"
        when :array then "array"
        when :hash then "object"
        else "string"
        end
      end
    end
  end
end
