# frozen_string_literal: true

require "fileutils"
require "json"

module Kumi
  module Dev
    module Codegen
      module_function

      def list
        available_schemas.each do |name|
          puts name
        end
      end

      def build!(schema_name, targets: %w[ruby], output_dir: nil)
        schema_path = find_schema_path(schema_name)
        raise "Schema '#{schema_name}' not found" unless schema_path

        output_dir ||= "codegen/#{schema_name}"
        FileUtils.mkdir_p(output_dir)

        targets.each do |target|
          case target
          when "ruby"
            build_ruby!(schema_path, output_dir)
          else
            puts "Warning: Unknown target '#{target}'"
          end
        end

        puts "Generated code in #{output_dir}"
      end

      def test!(*schema_names)
        names = schema_names.empty? ? available_schemas : schema_names.flatten
        success = true
        total_tests = 0
        passed_tests = 0

        names.each do |name|
          puts "Testing #{name}..."

          begin
            schema_success, schema_total, schema_passed = test_schema!(name)
            success &&= schema_success
            total_tests += schema_total
            passed_tests += schema_passed
          rescue StandardError => e
            puts "  ✗ #{name}: ERROR - #{e.message}"
            success = false
          end
        end

        puts "=== Test Summary ==="
        puts "Schemas: #{names.length}"
        puts "Total: #{total_tests}"
        puts "Passed: #{passed_tests}"
        puts "Failed: #{total_tests - passed_tests}"
        success_rate = total_tests > 0 ? (passed_tests.to_f / total_tests * 100).round(1) : 0
        puts "Success rate: #{success_rate}%"

        success
      end

      def verify!(schema_name)
        schema_path = find_schema_path(schema_name)
        raise "Schema '#{schema_name}' not found" unless schema_path

        output_dir = "codegen/#{schema_name}"
        expected_file = "#{output_dir}/expected.json"

        unless File.exist?(expected_file)
          puts "No expected outputs for #{schema_name}"
          return false
        end

        build!(schema_name, output_dir: output_dir)
        test_schema!(schema_name)
      end

      def schema_paths
        Dir.glob("golden/*/schema.kumi") + Dir.glob("schemas/*.kumi")
      end

      def available_schemas
        schema_paths.map do |path|
          if path.start_with?("golden/")
            # Extract schema name from golden/SCHEMA_NAME/schema.kumi
            path.split("/")[1]
          else
            # For standalone schemas, use the filename without extension
            File.basename(path, ".kumi")
          end
        end.uniq.sort
      end

      def find_schema_path(name)
        candidates = [
          "golden/#{name}/schema.kumi",
          "schemas/#{name}.kumi",
          name.end_with?(".kumi") ? name : "#{name}.kumi"
        ]

        candidates.find { |path| File.exist?(path) }
      end

      def build_ruby!(schema_path, output_dir)
        schema, = Kumi::Frontends.load(path: schema_path)
        result = Kumi::Analyzer.analyze!(schema)

        code = result.state[:ruby_codegen_files]["codegen.rb"]

        File.write("#{output_dir}/generated_code.rb", ruby_code)
        puts "  ✓ Ruby code generated"

        ruby_code
      end

      def test_schema!(schema_name)
        output_dir = "codegen/#{schema_name}"
        generated_file = "#{output_dir}/generated_code.rb"
        input_file = find_test_input(schema_name)
        expected_file = find_expected_output(schema_name)

        unless File.exist?(generated_file)
          puts "  ✗ No generated code found"
          return [false, 0, 0]
        end

        unless input_file && File.exist?(input_file)
          puts "  ✗ No test input found"
          return [false, 0, 0]
        end

        unless expected_file && File.exist?(expected_file)
          puts "  ✗ No expected output found"
          return [false, 0, 0]
        end

        code = File.read(generated_file)
        input_data = JSON.parse(File.read(input_file))
        expected_outputs = JSON.parse(File.read(expected_file))

        temp_file = "#{output_dir}/test_runner.rb"
        File.write(temp_file, code)

        begin
          load temp_file

          registry = Kumi::KernelRegistry.load_ruby
          program = Generated::Program.new(registry: registry)
          bound = program.from(input_data)

          total = expected_outputs.size
          passed = 0

          expected_outputs.each do |decl_name, expected_value|
            actual = bound[decl_name.to_sym]
            if actual == expected_value
              puts "  ✓ #{decl_name}: #{actual.inspect}"
              passed += 1
            else
              puts "  ✗ #{decl_name}: got #{actual.inspect}, expected #{expected_value.inspect}"
            end
          end

          [passed == total, total, passed]
        ensure
          FileUtils.rm_f(temp_file)
        end
      end

      def find_test_input(schema_name)
        candidates = [
          "golden/#{schema_name}/input.json",
          "codegen/#{schema_name}/input.json",
          "test/inputs/#{schema_name}.json"
        ]
        candidates.find { |path| File.exist?(path) }
      end

      def find_expected_output(schema_name)
        candidates = [
          "golden/#{schema_name}/expected.json",
          "codegen/#{schema_name}/expected.json",
          "test/outputs/#{schema_name}.json"
        ]
        candidates.find { |path| File.exist?(path) }
      end
    end
  end
end
