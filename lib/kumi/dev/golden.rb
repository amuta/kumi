# frozen_string_literal: true

require "fileutils"

module Kumi
  module Dev
    module Golden
      module_function

      REPRESENTATIONS = %w[ast nir].freeze

      def list
        golden_dirs.each do |name|
          puts name
        end
      end

      def record!(name = nil)
        names = name ? [name] : golden_dirs
        
        names.each do |schema_name|
          schema_path = golden_path(schema_name, "schema.kumi")
          unless File.exist?(schema_path)
            puts "Warning: #{schema_path} not found, skipping"
            next
          end

          expected_dir = golden_path(schema_name, "expected")
          FileUtils.mkdir_p(expected_dir)

          REPRESENTATIONS.each do |repr|
            puts "Recording #{schema_name}/#{repr}..."
            begin
              output = PrettyPrinter.send("generate_#{repr}", schema_path)
              if output
                File.write(File.join(expected_dir, "#{repr}.txt"), output)
                puts "  ✓ #{repr}.txt"
              else
                puts "  ✗ #{repr}.txt (no output)"
              end
            rescue => e
              puts "  ✗ #{repr}.txt (error: #{e.message})"
            end
          end
        end
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
            expected_file = File.join(expected_dir, "#{repr}.txt")
            tmp_file = File.join(tmp_dir, "#{repr}.txt")

            unless File.exist?(expected_file)
              puts "  ✗ #{repr} (no expected file)"
              success = false
              next
            end

            begin
              current_output = PrettyPrinter.send("generate_#{repr}", schema_path)
              unless current_output
                puts "  ✗ #{repr} (no current output)"
                success = false
                next
              end

              File.write(tmp_file, current_output)
              expected_content = File.read(expected_file)

              if current_output.strip == expected_content.strip
                puts "  ✓ #{repr}"
              else
                puts "  ✗ #{repr} (differs)"
                success = false
              end
            rescue => e
              puts "  ✗ #{repr} (error: #{e.message})"
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
          expected_file = File.join(expected_dir, "#{r}.txt")
          tmp_file = File.join(tmp_dir, "#{r}.txt")
          
          if File.exist?(expected_file) && File.exist?(tmp_file)
            puts "=== #{name}/#{r} ==="
            system("diff -u #{expected_file} #{tmp_file}")
            puts
          else
            puts "Cannot diff #{name}/#{r}: missing files"
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