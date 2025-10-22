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
      # Ensure JIT for golden tests
      Kumi.configure { |c| c.compilation_mode = :jit }

      # Idempotent loader for shared importable schemas used by text DSL tests
      def self.load_shared_schemas!
        dirs = []
        # Repo-root relative to this file
        dirs << File.expand_path("../../../golden/_shared", __dir__)
        # Repo-root relative to CWD (CI can run from repo root)
        dirs << File.expand_path("golden/_shared", Dir.pwd)
        # Bundler root, when available
        if defined?(Bundler) && Bundler.respond_to?(:root) && Bundler.root
          dirs << File.expand_path("golden/_shared", Bundler.root.to_s)
        end
        dirs.uniq.each do |dir|
          next unless File.directory?(dir)
          Dir.glob(File.join(dir, "*.rb")).sort.each { |f| require f }
        end

        # Precompile any loaded GoldenSchemas modules so imports can find trees
        if defined?(GoldenSchemas)
          GoldenSchemas.constants.each do |const|
            mod = GoldenSchemas.const_get(const)
            mod.runner if mod.is_a?(Module) && mod.respond_to?(:runner)
          end
        end
      end

      # Load immediately on require, safe to call again later
      load_shared_schemas!

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
