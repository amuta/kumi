# frozen_string_literal: true

require "fileutils"

module Kumi
  module Dev
    module Golden
      module_function

      REPRESENTATIONS = %w[ast nast snast irv2 binding_manifest].freeze
      JSON_REPRESENTATIONS = %w[irv2 binding_manifest].freeze

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

            extension = JSON_REPRESENTATIONS.include?(repr) ? "json" : "txt"
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
            extension = JSON_REPRESENTATIONS.include?(repr) ? "json" : "txt"
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

      def golden_dirs
        Dir.glob("golden/*/schema.kumi").map do |path|
          File.dirname(path).split("/").last
        end.sort
      end

      def golden_path(name, file)
        File.join("golden", name, file)
      end
    end
  end
end
