# frozen_string_literal: true

require "json"
require "open3"
require "bigdecimal"
require_relative "value_normalizer"

module Kumi
  module Dev
    module Golden
      class RuntimeTest
        attr_reader :schema_name, :language

        def initialize(schema_name, language)
          @schema_name = schema_name
          @language = language
        end

        def run(base_dir)
          # Skip JavaScript runtime tests for schemas with imports (requires generated shared modules)
          if language == :javascript && has_imports?(base_dir)
            return SchemaTestResult.new(
              schema_name: schema_name,
              skipped: true,
              skip_reason: "JavaScript runtime testing for schemas with imports requires generated shared modules"
            )
          end

          expected_outputs = load_expected_outputs(base_dir)
          actual_outputs = execute_schema(base_dir, expected_outputs.keys)

          test_results = expected_outputs.map do |decl_name, expected_value|
            RuntimeTestResult.new(
              schema_name: schema_name,
              decl_name: decl_name,
              expected: expected_value,
              actual: actual_outputs[decl_name],
              language: language
            )
          end

          SchemaTestResult.new(
            schema_name: schema_name,
            test_results: test_results
          )
        rescue StandardError => e
          SchemaTestResult.new(
            schema_name: schema_name,
            error: e.message
          )
        end

        private

        def has_imports?(base_dir)
          schema_file = File.join(base_dir, "schema.kumi")
          return false unless File.exist?(schema_file)
          File.read(schema_file).match?(/^\s*import\s+/)
        end

        def load_expected_outputs(base_dir)
          expected_file = File.join(base_dir, "expected.json")
          JSON.parse(File.read(expected_file))
        end

        def execute_schema(base_dir, decl_names)
          case language
          when :ruby
            execute_ruby(base_dir, decl_names)
          when :javascript
            execute_javascript(base_dir, decl_names)
          else
            raise "Unsupported language: #{language}"
          end
        end

        def execute_ruby(base_dir, decl_names)
          code_file = File.join(base_dir, "expected/schema_ruby.rb")
          input_file = File.join(base_dir, "input.json")

          code = File.read(code_file)
          input_data = JSON.parse(File.read(input_file))

          # Convert decimal string inputs to BigDecimal
          input_data = convert_decimal_strings(input_data)

          module_name = code.match(/module (Kumi::Compiled::\S+)/)[1]
          eval(code)
          module_const = Object.const_get(module_name)
          instance = module_const.from(input_data)

          decl_names.to_h { |name| [name, instance[name.to_sym]] }
        end

        def convert_decimal_strings(value)
          case value
          when Hash
            value.transform_values { |v| convert_decimal_strings(v) }
          when Array
            value.map { |v| convert_decimal_strings(v) }
          when String
            # Convert decimal-like strings to BigDecimal
            if value.match?(/\A-?\d+(\.\d+)?\z/)
              BigDecimal(value)
            else
              value
            end
          else
            value
          end
        end

        def execute_javascript(base_dir, decl_names)
          runner_path = File.expand_path("../support/kumi_runner.mjs", __dir__)
          raise "JS test runner not found at #{runner_path}" unless File.exist?(runner_path)

          module_path = File.absolute_path(File.join(base_dir, "expected/schema_javascript.mjs"))
          input_path = File.absolute_path(File.join(base_dir, "input.json"))
          decl_str = decl_names.join(",")

          command = "node #{runner_path} #{module_path} #{input_path} #{decl_str}"
          stdout, stderr, status = Open3.capture3(command)

          raise "JS runner failed for '#{schema_name}':\n#{stderr}" unless status.success?

          JSON.parse(stdout)
        end
      end
    end
  end
end
