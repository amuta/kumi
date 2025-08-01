# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      # Simple immutable state wrapper to prevent accidental mutations between passes
      class AnalysisState
        def initialize(data = {})
          @data = data.dup.freeze
        end

        # Get a value (same as hash access)
        def [](key)
          @data[key]
        end

        # Check if key exists (same as hash)
        def key?(key)
          @data.key?(key)
        end

        # Get all keys (same as hash)
        def keys
          @data.keys
        end

        # Create new state with additional data (simple and clean)
        def with(key, value)
          AnalysisState.new(@data.merge(key => value))
        end

        # Convert back to hash for final result
        def to_h
          @data.dup
        end
      end
    end
  end
end
