# frozen_string_literal: true

require "json"

module SchemaTestHelper
  # This helper provides a simple and efficient way to run schema fixtures in tests.
  #
  # It uses an in-memory cache (@compiled_cache) that persists for the duration of a
  # single `rspec` command. This ensures that each unique schema is only compiled
  # once, making the test suite significantly faster, while the use of anonymous
  # modules guarantees that tests are perfectly isolated from each other.

  # A class instance variable acts as a simple, run-long cache.

  # This is the main test helper. It can be used in two ways:
  #
  # 1. Convention-based (for complex data):
  #    run_schema_fixture("my_schema")
  #    -> This will load `spec/fixtures/schemas/my_schema.kumi`
  #    -> and `spec/fixtures/data/my_schema_input.json`
  #
  # 2. Direct data (for simple tests):
  #    run_schema_fixture("my_schema", input_data: { ... })
  #
  def run_schema_fixture(fixture_name, input_data: nil)
    @compiled_cache ||= {}
    # Check the in-memory cache for an already-compiled version of this schema.
    compiled_module = @compiled_cache[fixture_name]

    unless compiled_module
      #
      # CACHE MISS: This block runs only the first time a test encounters
      # a new fixture_name during a test run.
      #
      path = File.expand_path("../../fixtures/schemas/#{fixture_name}.kumi", __FILE__)
      raise "Schema fixture not found: #{path}" unless File.exist?(path)

      schema_content = File.read(path)

      # Define the schema in a new, anonymous module to prevent any global
      # namespace pollution, ensuring perfect test isolation.
      compiled_module = Module.new do
        extend Kumi::Schema

        # The `eval("proc { ... }")` pattern is used to correctly load the
        # file content as a block, preserving the DSL's syntactic sugar.
        schema_block = eval("proc { #{schema_content} }", binding, __FILE__, __LINE__)
        schema(&schema_block)
      end

      # Store the defined (but not yet run) module in the cache.
      # The actual compilation will be triggered by the `.from` call below,
      # using the on-demand compilation configured for the test environment.
      @compiled_cache[fixture_name] = compiled_module
    end

    # If input_data is not provided directly, load it from the conventional
    # JSON fixture file.
    final_input_data = if input_data
                         input_data
                       else
                         input_data_fixture_path = File.expand_path("../../fixtures/data/#{fixture_name}_input.json", __FILE__)
                         raise "Input data fixture not found: #{input_data_fixture_path}" unless File.exist?(input_data_fixture_path)

                         begin
                           JSON.parse(File.read(input_data_fixture_path), symbolize_names: true)
                         rescue StandardError => e
                           raise e.class, "Error loading input data fixture #{input_data_fixture_path}: #{e.message}"
                         end
                       end

    # CACHE HIT: For all subsequent requests for this fixture, the code jumps
    # directly here. It takes the cached module and executes it with the provided data.
    compiled_module.from(final_input_data)
  end
end

RSpec.configure do |config|
  config.include SchemaTestHelper

  # Optional but recommended: clear the cache before each full suite run.
  config.before(:suite) do
    SchemaTestHelper.instance_variable_set(:@compiled_cache, {})
  end
end
