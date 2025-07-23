# frozen_string_literal: true

# Helper for testing Sugar syntax that works around Ruby refinement limitations
# Since refinements only work at top-level contexts, we need to evaluate schemas
# outside of method contexts (like RSpec tests).

require_relative "../../lib/kumi"

module SugarTestHelper
  # Store compiled schemas that were created at top-level
  @@top_level_schemas = {}

  # Register a schema created at top-level for later use in tests
  def self.register_schema(name, schema)
    @@top_level_schemas[name] = schema
  end

  # Get a registered schema for use in tests
  def self.get_schema(name)
    @@top_level_schemas[name] || raise("Schema #{name} not found. Make sure to register it at top-level.")
  end

  # Helper method to run a registered schema with input data
  def self.run_schema(name, input_data)
    schema = get_schema(name)

    # The schema is an OpenStruct with runner and analysis
    # The runner was created with the compiled schema and definitions
    unless schema.respond_to?(:runner) && schema.respond_to?(:analysis)
      raise "Unexpected schema format: #{schema.class} - expected OpenStruct with runner and analysis"
    end

    # Get the template runner which has the correct structure
    template_runner = schema.runner

    # Get the compiled schema and node index from the template
    compiled_schema = template_runner.schema
    node_index = template_runner.node_index

    # Create a new runner with the actual input data but same schema and node_index
    Kumi::Runner.new(input_data, compiled_schema, node_index)
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
