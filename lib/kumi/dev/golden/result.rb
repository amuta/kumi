# frozen_string_literal: true

require_relative "value_normalizer"

module Kumi
  module Dev
    module Golden
      class Result
        attr_reader :schema_name, :representation, :status, :error

        def initialize(schema_name:, representation:, status:, error: nil)
          @schema_name = schema_name
          @representation = representation
          @status = status
          @error = error
        end

        def passed?
          status == :passed
        end

        def failed?
          status == :failed
        end

        def error?
          status == :error
        end
      end

      class GenerationResult < Result
        attr_reader :changed

        def initialize(schema_name:, representation:, status:, changed: false, error: nil)
          super(schema_name: schema_name, representation: representation, status: status, error: error)
          @changed = changed
        end

        def changed?
          @changed
        end
      end

      class VerificationResult < Result
        attr_reader :diff

        def initialize(schema_name:, representation:, status:, diff: nil, error: nil)
          super(schema_name: schema_name, representation: representation, status: status, error: error)
          @diff = diff
        end
      end

      class RuntimeTestResult
        attr_reader :schema_name, :decl_name, :expected, :actual, :language

        def initialize(schema_name:, decl_name:, expected:, actual:, language:)
          @schema_name = schema_name
          @decl_name = decl_name
          @expected = expected
          @actual = actual
          @language = language
        end

        def passed?
          ValueNormalizer.values_equal?(actual, expected, language: language)
        end

        def failed?
          !passed?
        end
      end

      class SchemaTestResult
        attr_reader :schema_name, :test_results, :error, :skipped, :skip_reason

        def initialize(schema_name:, test_results: [], error: nil, skipped: false, skip_reason: nil)
          @schema_name = schema_name
          @test_results = test_results
          @error = error
          @skipped = skipped
          @skip_reason = skip_reason
        end

        def passed?
          skipped? || (error.nil? && test_results.all?(&:passed?))
        end

        def failed?
          !passed?
        end

        def skipped?
          skipped
        end

        def passed_count
          test_results.count(&:passed?)
        end

        def total_count
          test_results.size
        end
      end
    end
  end
end
