# frozen_string_literal: true

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
      # Precompile shared schemas so __kumi_syntax_tree__ is available for imports
      def self.precompile_schemas!
        if defined?(Kumi::TestSharedSchemas)
          Kumi::TestSharedSchemas.constants.each do |const|
            mod = Kumi::TestSharedSchemas.const_get(const)
            mod.runner if mod.is_a?(Module) && mod.respond_to?(:runner)
          end
        end
      end

      module_function

      def list = suite.list

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
        ruby_results = ruby_names.map { |n| RuntimeTest.new(n, :ruby).run(suite.send(:schema_dir, n)) }

        js_names = suite.send(:filter_testable_schemas, names, :javascript)
        js_results = js_names.map { |n| RuntimeTest.new(n, :javascript).run(suite.send(:schema_dir, n)) }

        Reporter.new.report_runtime_tests(ruby: ruby_results, javascript: js_results)
      end

      def test_codegen!(*names_arg)
        names_arg = [names_arg].flatten.compact
        names = names_arg.any? ? names_arg : suite.send(:schema_names)
        testable = suite.send(:filter_testable_schemas, names, :ruby)
        results = testable.map { |n| RuntimeTest.new(n, :ruby).run(suite.send(:schema_dir, n)) }
        Reporter.new.report_runtime_tests(ruby: results)
      end

      def test_js_codegen!(*names_arg)
        names_arg = [names_arg].flatten.compact
        names = names_arg.any? ? names_arg : suite.send(:schema_names)
        testable = suite.send(:filter_testable_schemas, names, :javascript)
        results = testable.map { |n| RuntimeTest.new(n, :javascript).run(suite.send(:schema_dir, n)) }
        Reporter.new.report_runtime_tests(javascript: results)
      end

      def suite
        @suite ||= Suite.new
      end
    end
  end
end
