# frozen_string_literal: true

# NOTE: THIS COULD BE JUST LIKE THE NODE_INDEX - INDEXED BY THE NODE ID
module Kumi
  module Core
    module Analyzer
      module Structs
        # Represents metadata for a single input field produced by InputCollector
        InputMeta = Struct.new(
          :type,
          :domain,
          :container,
          :access_mode,
          :enter_via,
          :consume_alias,
          :children,
          :dimensional_scope,
          keyword_init: true
        ) do
          def deep_freeze!
            if children
              children.each_value(&:deep_freeze!)
              children.freeze
            end
            freeze
          end
        end
      end
    end
  end
end
