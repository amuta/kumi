# frozen_string_literal: true

module Kumi::Core
  module Export
    class Serializer
      include NodeSerializers

      def initialize(pretty: false, include_locations: false)
        @pretty = pretty
        @include_locations = include_locations
      end

      def serialize(syntax_root)
        json_data = {
          kumi_version: VERSION,
          ast: serialize_root(syntax_root)
        }

        @pretty ? JSON.pretty_generate(json_data) : JSON.generate(json_data)
      end
    end
  end
end
