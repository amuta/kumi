# frozen_string_literal: true

require "fileutils"
# require "tmpdir"

module Kumi
  module Dev
    module Golden
      module_function

      # REPRESENTATIONS = %w[ast nast snast irv2 binding_manifest generated_code planning pack].freeze
      REPRESENTATIONS = %w[ast nast snast lir_00_unoptimized lir_01_hoist_scalar_references lir_02_inlined lir_03_cse lir_04_loop_invcm lir_05_const_prop
                           lir_01_hoist_scalar_references generated_code].freeze
      JSON_REPRESENTATIONS = %w[irv2 binding_manifest planning pack].freeze
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
            if repr == "pack"
              # Handle pack files specially - generate target-specific files
              begin
                require_relative "../pack/builder"
                ir, planning, bindings, inputs, module_id = Kumi::Pack::Builder.generate_artifacts(schema_path)
                pack = Kumi::Pack::Builder.assemble_pack(module_id, ir, planning, bindings, inputs, %w[ruby], false)
                current_output = Kumi::Pack::Builder.canonical_json(pack)

                pack_file = File.join(expected_dir, "pack.json")
                if File.exist?(pack_file)
                  expected_content = File.read(pack_file)
                  if current_output != expected_content
                    File.write(pack_file, current_output)
                    puts "  #{schema_name}/pack.json (updated)"
                    schema_changed = true
                    changed_any = true
                  end
                else
                  # New file
                  File.write(pack_file, current_output)
                  puts "  #{schema_name}/pack.json (created)"
                  schema_changed = true
                  changed_any = true
                end
              rescue StandardError => e
                puts "  ✗ #{schema_name}/pack (error: #{e.message})"
                raise
              end
              next
            end

            current_output = PrettyPrinter.send("generate_#{repr}", schema_path)
            # puts "generating #{repr}"
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

          schema_success = true
          failed_reprs = []

          REPRESENTATIONS.each do |repr|
            if repr == "pack"
              # Handle pack verification specially
              expected_pack_file = File.join(expected_dir, "pack.json")
              unless File.exist?(expected_pack_file)
                failed_reprs << "pack.json (no expected file)"
                schema_success = false
                success = false
                next
              end

              begin
                require_relative "../pack/builder"
                current_pack_output = Kumi::Pack::Builder.print(schema: schema_path, targets: %w[ruby])
                File.write(File.join(tmp_dir, "pack.json"), current_pack_output)

                expected_content = File.read(expected_pack_file)
                unless current_pack_output.strip == expected_content.strip
                  failed_reprs << "pack.json"
                  schema_success = false
                  success = false
                end
              rescue StandardError => e
                failed_reprs << "pack.json (error: #{e.message})"
                schema_success = false
                success = false
              end
              next
            end

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

          # Show schema result
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
            if r == "pack"
              # Handle pack diffing specially
              expected_file = File.join(expected_dir, "pack.json")
              tmp_file = File.join(tmp_dir, "pack.json")

              if File.exist?(expected_file) && File.exist?(tmp_file)
                # Check if files actually differ before showing diff
                expected_content = File.read(expected_file)
                tmp_content = File.read(tmp_file)
                if expected_content.strip != tmp_content.strip
                  puts "=== #{schema_name}/pack.json ==="
                  json_diff(expected_file, tmp_file)
                  puts
                end
              elsif File.exist?(expected_file) || File.exist?(tmp_file)
                puts "Cannot diff #{schema_name}/pack.json: missing files"
              end
              next
            end

            extension = JSON_REPRESENTATIONS.include?(r) ? "json" : "txt"
            expected_file = File.join(expected_dir, "#{r}.#{extension}")
            tmp_file = File.join(tmp_dir, "#{r}.#{extension}")
            filename = "#{r}.#{extension}"

            if File.exist?(expected_file) && File.exist?(tmp_file)
              # Check if files actually differ before showing diff
              expected_content = File.read(expected_file)
              tmp_content = File.read(tmp_file)
              if expected_content.strip != tmp_content.strip
                puts "=== #{schema_name}/#{filename} ==="
                if JSON_REPRESENTATIONS.include?(r)
                  json_diff(expected_file, tmp_file)
                else
                  system("diff -u #{expected_file} #{tmp_file}")
                end
                puts
              end
            elsif File.exist?(expected_file) || File.exist?(tmp_file)
              puts "Cannot diff #{schema_name}/#{filename}: missing files"
            end
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

            # Load pack.json to get module name
            pack_file = golden_path(schema_name, "expected/pack.json")
            module_name = if File.exist?(pack_file)
                            pack_data = JSON.parse(File.read(pack_file))
                            pack_data["module_id"]
                          else
                            "schema_module" # default fallback
                          end

            # Create a temporary file in the golden tmp directory and load it
            tmp_dir = golden_path(schema_name, "tmp")
            FileUtils.mkdir_p(tmp_dir)
            temp_file = File.join(tmp_dir, "test_generated_code.rb")
            File.write(temp_file, code)

            # Load the generated code
            load temp_file

            # Create runtime using the dynamically determined module
            Kumi::KernelRegistry.load_ruby
            module_const = Object.const_get(module_name.split("_").map(&:capitalize).join)
            bound = module_const.from(input_data)

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
              rescue StandardError
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
          rescue StandardError
            # puts "  ✗ #{schema_name}: SYSTEM ERROR - #{e.message}"
            # puts "    System backtrace:"
            # e.backtrace.first(10).each_with_index do |line, i|
            #   puts "      #{i + 1}. #{line}"
            # end
            success = false
            raise
          end

          clean_tmp_dirs!(names)
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

      def json_diff(expected_file, tmp_file)
        # Require jq for JSON diffing in dev/CI
        unless system("which jq > /dev/null 2>&1")
          abort "jq is required for JSON diffing. Please install jq: apt-get install jq / brew install jq"
        end

        # Create pretty-printed temporary files
        expected_pretty = "#{expected_file}.pretty"
        tmp_pretty = "#{tmp_file}.pretty"

        begin
          system("jq . #{expected_file} > #{expected_pretty}")
          system("jq . #{tmp_file} > #{tmp_pretty}")
          system("diff -u #{expected_pretty} #{tmp_pretty}")
        ensure
          File.unlink(expected_pretty) if File.exist?(expected_pretty)
          File.unlink(tmp_pretty) if File.exist?(tmp_pretty)
        end
      end

      def test_lir_codegen!(name = nil)
        require "json"

        names = name ? [name] : golden_dirs_with_codegen
        success = true

        names.each do |schema_name|
          puts "Testing LIR codegen for #{schema_name}..."

          begin
            # Required files
            generated_code_file = golden_path(schema_name, "expected/generated_code.rb")
            input_file = golden_path(schema_name, "input.json")
            expected_file = golden_path(schema_name, "expected.json")

            unless File.exist?(generated_code_file) && File.exist?(input_file) && File.exist?(expected_file)
              puts "  ✗ Missing required files"
              success = false
              next
            end

            # Load files
            code = File.read(generated_code_file)
            input_data = JSON.parse(File.read(input_file))
            expected_outputs = JSON.parse(File.read(expected_file))

            # Load the generated code
            eval(code)

            # Create an instance of the program
            program_instance = KumiProgram.from(input_data)

            # Run the generated program and collect all results
            result = {}
            expected_outputs.each_key do |decl_name|
              result[decl_name] = program_instance[decl_name.to_sym]
            end

            # Assert that the result matches the expected output
            if result.to_json == expected_outputs.to_json
              puts "  ✓ #{schema_name}: PASSED"
            else
              puts "  ✗ #{schema_name}: FAILED"
              puts "    Expected: #{expected_outputs.to_json}"
              puts "    Actual:   #{result.to_json}"
              puts "    Raw Expected: #{expected_outputs.inspect}"
              puts "    Raw Actual:   #{result.inspect}"
              success = false
            end
          rescue StandardError => e
            puts "  ✗ #{schema_name}: ERROR - #{e.message}"
            e.backtrace.first(5).each { |line| puts "    #{line}" }
            success = false
          end
        end

        success
      end
    end
  end
end
