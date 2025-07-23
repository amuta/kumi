# frozen_string_literal: true

module Kumi
  module Export
    class Deserializer
      include NodeBuilders

      def initialize(validate: true)
        @validate = validate
      end

      def deserialize(json_string)
        data = parse_json(json_string)
        validate_format(data) if @validate

        build_node(data[:ast])
      end

      private

      def parse_json(json_string)
        JSON.parse(json_string, symbolize_names: true)
      rescue JSON::ParserError => e
        raise Kumi::Export::Errors::DeserializationError, "Invalid JSON: #{e.message}"
      end

      def validate_format(data)
        unless data[:kumi_version] && data[:ast]
          raise Kumi::Export::Errors::DeserializationError,
                "Missing required fields: kumi_version, ast"
        end

        return if data[:ast][:type] == "root"

        raise Kumi::Export::Errors::DeserializationError, "Root node must have type 'root'"
      end
    end
  end
end
