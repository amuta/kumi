# frozen_string_literal: true

# Helper for testing Sugar syntax that works around Ruby refinement limitations
# Since refinements only work at top-level contexts, we need to evaluate schemas
# outside of method contexts (like RSpec tests).

module SugarTestHelper
  # Store compiled schemas that were created at top-level
  @top_level_schemas = {}

  # Register a schema created at top-level for later use in tests
  def self.register_schema(name, schema)
    @top_level_schemas[name] = schema
  end

  # Get a registered schema for use in tests
  def self.get_schema(name)
    @top_level_schemas[name] || raise("Schema #{name} not found. Make sure to register it at top-level.")
  end

  # Helper method to run a registered schema with input data
  def self.run_schema(name, input_data)
    schema = get_schema(name)

    # When capture an schema declaration, it should provide us an instance of Kumi::Schema::Inspector
    raise "Expected schema to be an instance of Kumi::Schema::Inspector, got #{schema.class}" unless schema.is_a?(Kumi::Schema::Inspector)

    Kumi::Core::SchemaInstance.new(schema.compiled_schema, schema.analyzer_result.definitions, input_data)
  end

  # For use in specs - include this module to get access to helper methods
  module SpecMethods
    def run_sugar_schema(name, input_data)
      SugarTestHelper.run_schema(name, input_data)
    end

    def expect_sugar_schema(name, input_data)
      runner = run_sugar_schema(name, input_data)
      yield(runner) if block_given?
      runner
    end
  end
end

# Make helper methods available in specs
RSpec.configure do |config|
  config.include SugarTestHelper::SpecMethods
end
