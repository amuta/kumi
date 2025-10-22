# frozen_string_literal: true

# Load Schema first so CompiledSchemaWrapper is available
require_relative "../schema"

require_relative "golden/representation"
require_relative "golden/result"
require_relative "golden/generator"
require_relative "golden/verifier"
require_relative "golden/runtime_test"
require_relative "golden/reporter"
require_relative "golden/suite"

module Kumi
  module Dev
    module Golden
      # Configure Kumi for golden tests (JIT compilation for dynamic schemas)
      Kumi.configure do |config|
        config.compilation_mode = :jit
      end

      # Load shared golden schemas for import support (only when using golden tests)
      shared_dir = File.expand_path("../../../golden/_shared", __dir__)
      if File.directory?(shared_dir)
        Dir.glob("#{shared_dir}/*.rb").sort.each do |f|
          require f
        end
        # Compile all shared schemas so imports can find their syntax trees
        GoldenSchemas.constants.each do |const|
          schema_module = GoldenSchemas.const_get(const)
          if schema_module.is_a?(Module) && schema_module.respond_to?(:runner)
            schema_module.runner
          end
        end
      end

      module_function

      def list
        suite.list
      end

      def update!(*names)
        names = [names].flatten.compact
        names = nil if names.empty?
        suite.update(names)
      end

      def verify!(*names)
        names = [names].flatten.compact
        names = nil if names.empty?
        suite.verify(names)
      end

      def diff!(*names)
        names = [names].flatten.compact
        names = nil if names.empty?
        suite.diff(names)
      end

      def test_all_codegen!(*names_arg)
        names_arg = [names_arg].flatten.compact
        names = names_arg.any? ? names_arg : suite.send(:schema_names)

        ruby_names = suite.send(:filter_testable_schemas, names, :ruby)
        ruby_results = ruby_names.map do |schema_name|
          RuntimeTest.new(schema_name, :ruby).run(suite.send(:schema_dir, schema_name))
        end

        js_names = suite.send(:filter_testable_schemas, names, :javascript)
        js_results = js_names.map do |schema_name|
          RuntimeTest.new(schema_name, :javascript).run(suite.send(:schema_dir, schema_name))
        end

        Reporter.new.report_runtime_tests(ruby: ruby_results, javascript: js_results)
      end

      def test_codegen!(*names_arg)
        names_arg = [names_arg].flatten.compact
        names = names_arg.any? ? names_arg : suite.send(:schema_names)
        testable_names = suite.send(:filter_testable_schemas, names, :ruby)
        results = testable_names.map do |schema_name|
          RuntimeTest.new(schema_name, :ruby).run(suite.send(:schema_dir, schema_name))
        end
        Reporter.new.report_runtime_tests(ruby: results)
      end

      def test_js_codegen!(*names_arg)
        names_arg = [names_arg].flatten.compact
        names = names_arg.any? ? names_arg : suite.send(:schema_names)
        testable_names = suite.send(:filter_testable_schemas, names, :javascript)
        results = testable_names.map do |schema_name|
          RuntimeTest.new(schema_name, :javascript).run(suite.send(:schema_dir, schema_name))
        end
        Reporter.new.report_runtime_tests(javascript: results)
      end

      def suite
        @suite ||= Suite.new
      end
    end
  end
end
