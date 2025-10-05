# frozen_string_literal: true

require "fileutils"
require "json"
require "open3" # For robustly running external commands

module Kumi
  module Dev
    module Golden
      module_function

      REPRESENTATIONS = %w[ast input_plan nast snast lir_00_unoptimized lir_01_hoist_scalar_references lir_02_inlined lir_04_1_loop_fusion lir_03_cse
                           lir_04_loop_invcm lir_06_const_prop
                           schema_ruby schema_javascript].freeze
      RUBY_REPRESENTATIONS = %w[schema_ruby].freeze
      JS_REPRESENTATIONS = %w[schema_javascript].freeze

      def list
        golden_dirs.each do |name|
          puts name
        end
      end

      def update!(name = nil)
        names = name ? [name] : golden_dirs
        changed_any = false

        names.each do |schema_name|
          schema_path = golden_path(schema_name, "schema.kumi")
          unless File.exist?(schema_path)
            puts "Warning: #{schema_path} not found, skipping"
            next
          end

          expected_dir = golden_path(schema_name, "expected")
          FileUtils.mkdir_p(expected_dir)

          schema_changed = false

          REPRESENTATIONS.each do |repr|
            current_output = PrettyPrinter.send("generate_#{repr}", schema_path)
            next unless current_output

            extension = if RUBY_REPRESENTATIONS.include?(repr)
                          "rb"
                        elsif JS_REPRESENTATIONS.include?(repr)
                          "js"
                        else
                          "txt"
                        end
            filename = "#{repr}.#{extension}"
            expected_file = File.join(expected_dir, filename)

            if File.exist?(expected_file)
              expected_content = File.read(expected_file)
              if current_output.strip != expected_content.strip
                File.write(expected_file, current_output)
                puts "  #{schema_name}/#{filename} (updated)"
                schema_changed = true
                changed_any = true
              end
            else
              File.write(expected_file, current_output)
              puts "  #{schema_name}/#{filename} (created)"
              schema_changed = true
              changed_any = true
            end
          rescue StandardError => e
            puts "  ✗ #{schema_name}/#{repr} (error: #{e.message})"
            raise
          end

          puts "  #{schema_name} (no changes)" unless schema_changed
        end

        puts "No changes detected" unless changed_any
      end

      def verify!(name = nil)
        names = name ? [name] : golden_dirs
        success = true

        names.each do |schema_name|
          schema_path = golden_path(schema_name, "schema.kumi")
          unless File.exist?(schema_path)
            puts "Warning: #{schema_path} not found, skipping"
            next
          end

          expected_dir = golden_path(schema_name, "expected")
          tmp_dir = golden_path(schema_name, "tmp")
          FileUtils.mkdir_p(tmp_dir)

          schema_success = true
          failed_reprs = []

          REPRESENTATIONS.each do |repr|
            extension = if RUBY_REPRESENTATIONS.include?(repr)
                          "rb"
                        elsif JS_REPRESENTATIONS.include?(repr)
                          "js"
                        else
                          "txt"
                        end
            expected_file = File.join(expected_dir, "#{repr}.#{extension}")
            tmp_file = File.join(tmp_dir, "#{repr}.#{extension}")
            filename = "#{repr}.#{extension}"

            unless File.exist?(expected_file)
              failed_reprs << "#{filename} (no expected file)"
              schema_success = false
              success = false
              next
            end

            begin
              current_output = PrettyPrinter.send("generate_#{repr}", schema_path)
              unless current_output
                failed_reprs << "#{filename} (no current output)"
                schema_success = false
                success = false
                next
              end

              File.write(tmp_file, current_output)
              expected_content = File.read(expected_file)

              unless current_output.strip == expected_content.strip
                failed_reprs << filename
                schema_success = false
                success = false
              end
            rescue StandardError => e
              failed_reprs << "#{filename} (error: #{e.message})"
              schema_success = false
              success = false
            end
          end

          if schema_success
            puts "✓ #{schema_name}"
          else
            puts "✗ #{schema_name} (#{failed_reprs.join(', ')})"
          end
        end

        success
      end

      def diff!(name = nil, repr = nil)
        names = name ? [name] : golden_dirs

        names.each do |schema_name|
          expected_dir = golden_path(schema_name, "expected")
          tmp_dir = golden_path(schema_name, "tmp")

          representations = repr ? [repr] : REPRESENTATIONS

          representations.each do |r|
            extension = "txt"
            expected_file = File.join(expected_dir, "#{r}.#{extension}")
            tmp_file = File.join(tmp_dir, "#{r}.#{extension}")
            filename = "#{r}.#{extension}"

            if File.exist?(expected_file) && File.exist?(tmp_file)
              # Check if files actually differ before showing diff
              expected_content = File.read(expected_file)
              tmp_content = File.read(tmp_file)
              if expected_content.strip != tmp_content.strip
                puts "=== #{schema_name}/#{filename} ==="
                system("diff -u #{expected_file} #{tmp_file}")
                puts
              end
            elsif File.exist?(expected_file) || File.exist?(tmp_file)
              puts "Cannot diff #{schema_name}/#{filename}: missing files"
            end
          end
        end
      end

      def test_codegen!(name = nil)
        names = name ? [name] : golden_dirs_with_ruby_codegen
        run_codegen_tests(names, :ruby)
      end

      def test_js_codegen!(name = nil)
        names = name ? [name] : golden_dirs_with_js_codegen
        run_codegen_tests(names, :javascript)
      end

      def run_codegen_tests(names, language)
        total_tests = 0
        passed_tests = 0
        success = true

        names.each do |schema_name|
          puts "Testing #{language.to_s.upcase} codegen for #{schema_name}..."
          schema_passed = true
          begin
            expected_file = golden_path(schema_name, "expected.json")
            expected_outputs = JSON.parse(File.read(expected_file))
            actual_outputs = execute_schema(schema_name, expected_outputs.keys, language)

            # Test each expected output
            schema_passed, schema_correct = compare_outputs(expected_outputs, actual_outputs)
            total_tests += expected_outputs.size
            passed_tests += schema_correct

            success &&= schema_passed

            if schema_passed
              puts "  🎉 #{schema_name}: ALL #{expected_outputs.size} outputs correct"
            else
              puts "  ⚠️  #{schema_name}: #{schema_correct}/#{expected_outputs.size} outputs correct"
            end
          rescue StandardError => e
            puts "  ✗ #{schema_name}: SYSTEM ERROR - #{e.message}"
            puts(e.backtrace.first(5).map { |line| "    #{line}" })
            success = false
          end
          puts
        end

        print_summary(language, names.length, total_tests, passed_tests)
        success
      end

      def execute_schema(schema_name, decl_names, language)
        case language
        when :ruby
          execute_ruby(schema_name, decl_names)
        when :javascript
          execute_javascript(schema_name, decl_names)
        else
          raise "Unsupported language: #{language}"
        end
      end

      def execute_ruby(schema_name, decl_names)
        code_file = golden_path(schema_name, "expected/schema_ruby.rb")
        input_file = golden_path(schema_name, "input.json")

        code = File.read(code_file)
        input_data = JSON.parse(File.read(input_file))

        # Dynamically load and run the Ruby module
        module_name = code.match(/module (Kumi::Compiled::\S+)/)[1]
        eval(code) # Use eval to load the module into the current context
        module_const = Object.const_get(module_name)
        instance = module_const.from(input_data)

        decl_names.to_h { |name| [name, instance[name.to_sym]] }
      end

      def execute_javascript(schema_name, decl_names)
        runner_path = File.expand_path("support/kumi_runner.js", __dir__)
        raise "JS test runner not found at #{runner_path}" unless File.exist?(runner_path)

        module_path = File.absolute_path(golden_path(schema_name, "expected/schema_javascript.js"))
        input_path = File.absolute_path(golden_path(schema_name, "input.json"))
        decl_str = decl_names.join(",")

        command = "node #{runner_path} #{module_path} #{input_path} #{decl_str}"
        stdout, stderr, status = Open3.capture3(command)

        raise "JS runner failed for '#{schema_name}':\n#{stderr}" unless status.success?

        JSON.parse(stdout)
      end

      def compare_outputs(expected_outputs, actual_outputs)
        schema_passed = true
        schema_correct = 0

        expected_outputs.each do |decl_name, expected_value|
          actual_result = actual_outputs[decl_name]
          if actual_result == expected_value
            # Uncomment for verbose success logging
            # puts "  ✓ #{decl_name}"
            schema_correct += 1
          else
            puts "  ✗ #{decl_name}: got #{actual_result.inspect}, expected #{expected_value.inspect}"
            schema_passed = false
          end
        end
        [schema_passed, schema_correct]
      end

      def print_summary(language, schema_count, total_tests, passed_tests)
        puts "=== #{language.to_s.upcase} Codegen Test Summary ==="
        puts "Schemas tested: #{schema_count}"
        puts "Total outputs: #{total_tests}"
        puts "Passed: #{passed_tests}"
        puts "Failed: #{total_tests - passed_tests}"
        success_rate = total_tests.positive? ? (passed_tests.to_f / total_tests * 100).round(1) : 0
        puts "Success rate: #{success_rate}%"
        puts "============================"
      end

      def golden_dirs
        Dir.glob("golden/*/schema.kumi").map { |path| File.basename(File.dirname(path)) }.sort
      end

      def golden_dirs_with_ruby_codegen
        golden_dirs.select do |name|
          File.exist?(golden_path(name, "expected/schema_ruby.rb")) &&
            File.exist?(golden_path(name, "input.json")) &&
            File.exist?(golden_path(name, "expected.json"))
        end
      end

      def golden_dirs_with_js_codegen
        golden_dirs.select do |name|
          File.exist?(golden_path(name, "expected/schema_javascript.js")) &&
            File.exist?(golden_path(name, "input.json")) &&
            File.exist?(golden_path(name, "expected.json"))
        end
      end

      def golden_path(name, file)
        File.join("golden", name, file)
      end
    end
  end
end
