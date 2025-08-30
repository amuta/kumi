# frozen_string_literal: true

require "fileutils"
# require "tmpdir"

module Kumi
  module Dev
    module Golden
      module_function

      REPRESENTATIONS = %w[ast nast snast irv2 binding_manifest generated_code].freeze
      JSON_REPRESENTATIONS = %w[irv2 binding_manifest].freeze
      RUBY_REPRESENTATIONS = %w[generated_code].freeze

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

            extension = if JSON_REPRESENTATIONS.include?(repr)
                          "json"
                        elsif RUBY_REPRESENTATIONS.include?(repr)
                          "rb"
                        else
                          "txt"
                        end
            filename = "#{repr}.#{extension}"
            expected_file = File.join(expected_dir, filename)

            # Check if file exists and content differs
            if File.exist?(expected_file)
              expected_content = File.read(expected_file)
              if current_output.strip != expected_content.strip
                File.write(expected_file, current_output)
                puts "  #{schema_name}/#{filename} (updated)"
                schema_changed = true
                changed_any = true
              end
            else
              # New file
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

          puts "Verifying #{schema_name}..."

          REPRESENTATIONS.each do |repr|
            extension = if JSON_REPRESENTATIONS.include?(repr)
                          "json"
                        elsif RUBY_REPRESENTATIONS.include?(repr)
                          "rb"
                        else
                          "txt"
                        end
            expected_file = File.join(expected_dir, "#{repr}.#{extension}")
            tmp_file = File.join(tmp_dir, "#{repr}.#{extension}")
            filename = "#{repr}.#{extension}"

            unless File.exist?(expected_file)
              puts "  ✗ #{filename} (no expected file)"
              success = false
              next
            end

            begin
              current_output = PrettyPrinter.send("generate_#{repr}", schema_path)
              unless current_output
                puts "  ✗ #{filename} (no current output)"
                success = false
                next
              end

              File.write(tmp_file, current_output)
              expected_content = File.read(expected_file)

              if current_output.strip == expected_content.strip
                puts "  ✓ #{filename}"
              else
                puts "  ✗ #{filename} (differs)"
                success = false
              end
            rescue StandardError => e
              puts "  ✗ #{filename} (error: #{e.message})"
              puts "Backtrace:" + e.backtrace.first(10).join("\n")
              success = false
            end
          end
        end

        success
      end

      def diff!(name, repr = nil)
        expected_dir = golden_path(name, "expected")
        tmp_dir = golden_path(name, "tmp")

        representations = repr ? [repr] : REPRESENTATIONS

        representations.each do |r|
          extension = JSON_REPRESENTATIONS.include?(r) ? "json" : "txt"
          expected_file = File.join(expected_dir, "#{r}.#{extension}")
          tmp_file = File.join(tmp_dir, "#{r}.#{extension}")
          filename = "#{r}.#{extension}"

          if File.exist?(expected_file) && File.exist?(tmp_file)
            puts "=== #{name}/#{filename} ==="
            system("diff -u #{expected_file} #{tmp_file}")
            puts
          else
            puts "Cannot diff #{name}/#{filename}: missing files"
          end
        end
      end

      def test_codegen!(name = nil)
        require "json"

        names = name ? [name] : golden_dirs_with_codegen
        success = true
        total_tests = 0
        passed_tests = 0

        # Clean tmp directories before testing
        clean_tmp_dirs!(names)

        names.each do |schema_name|
          puts "Testing codegen for #{schema_name}..."

          begin
            # Required files
            generated_code_file = golden_path(schema_name, "expected/generated_code.rb")
            input_file = golden_path(schema_name, "input.json")
            expected_file = golden_path(schema_name, "expected.json")

            unless File.exist?(generated_code_file) && File.exist?(input_file) && File.exist?(expected_file)
              puts "  ✗ Missing required files:"
              puts "    generated_code.rb: #{File.exist?(generated_code_file)}"
              puts "    input.json: #{File.exist?(input_file)}"
              puts "    expected.json: #{File.exist?(expected_file)}"
              success = false
              next
            end

            # Load files
            code = File.read(generated_code_file)
            input_data = JSON.parse(File.read(input_file))
            expected_outputs = JSON.parse(File.read(expected_file))

            # Create a temporary file in the golden tmp directory and load it
            tmp_dir = golden_path(schema_name, "tmp")
            FileUtils.mkdir_p(tmp_dir)
            temp_file = File.join(tmp_dir, "test_generated_code.rb")
            File.write(temp_file, code)

            # Load the generated code
            load temp_file

            # Create runtime using the Generated module
            registry = Kumi::KernelRegistry.load_ruby
            program = Generated::Program.new(registry: registry)
            bound = program.from(input_data)

            # NOTE: We keep test_generated_code.rb for debugging - it's in tmp/ which is ignored

            # Test each expected output
            schema_passed = true
            schema_total = expected_outputs.size
            schema_correct = 0

            expected_outputs.each do |decl_name, expected_value|
              total_tests += 1
              begin
                actual_result = bound[decl_name.to_sym]

                if actual_result == expected_value
                  puts "  ✓ #{decl_name}: #{actual_result.inspect}"
                  schema_correct += 1
                  passed_tests += 1
                else
                  puts "  ✗ #{decl_name}: got #{actual_result.inspect}, expected #{expected_value.inspect}"
                  schema_passed = false
                  success = false
                end
              rescue StandardError => e
                # puts "  ✗ #{decl_name}: ERROR - #{e.message}"
                # puts "    Backtrace:"
                # e.backtrace.first(10).each_with_index do |line, i|
                #   puts "      #{i + 1}. #{line}"
                # end
                schema_passed = false
                success = false
                raise
              end
            end

            if schema_passed
              puts "  🎉 #{schema_name}: ALL #{schema_total} outputs correct"
            else
              puts "  ⚠️  #{schema_name}: #{schema_correct}/#{schema_total} outputs correct"
            end
          rescue StandardError => e
            # puts "  ✗ #{schema_name}: SYSTEM ERROR - #{e.message}"
            # puts "    System backtrace:"
            # e.backtrace.first(10).each_with_index do |line, i|
            #   puts "      #{i + 1}. #{line}"
            # end
            success = false
            raise
          end

          puts
        end

        puts "=== Codegen Test Summary ==="
        puts "Schemas tested: #{names.length}"
        puts "Total outputs: #{total_tests}"
        puts "Passed: #{passed_tests}"
        puts "Failed: #{total_tests - passed_tests}"
        success_rate = total_tests > 0 ? (passed_tests.to_f / total_tests * 100).round(1) : 0
        puts "Success rate: #{success_rate}%"

        success
      end

      def golden_dirs
        Dir.glob("golden/*/schema.kumi").map do |path|
          File.dirname(path).split("/").last
        end.sort
      end

      def golden_dirs_with_codegen
        golden_dirs.select do |name|
          File.exist?(golden_path(name, "expected/generated_code.rb")) &&
            File.exist?(golden_path(name, "input.json")) &&
            File.exist?(golden_path(name, "expected.json"))
        end
      end

      def clean_tmp_dirs!(names)
        names.each do |schema_name|
          tmp_dir = golden_path(schema_name, "tmp")
          next unless File.exist?(tmp_dir)

          # Remove test-specific files, keep the main golden files
          test_files = %w[test_generated_code.rb]
          test_files.each do |file|
            file_path = File.join(tmp_dir, file)
            FileUtils.rm_f(file_path)
          end
        end
      end

      def golden_path(name, file)
        File.join("golden", name, file)
      end
    end
  end
end
