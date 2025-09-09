# frozen_string_literal: true

require "fileutils"

module Kumi
  module Dev
    module Parse
      module_function

      def run(schema_path, opts = {})
        # Load schema via text frontend
        begin
          schema, _inputs = Kumi::Frontends::Text.load(path: schema_path)
        rescue LoadError
          puts "Error: kumi-parser gem not available. Install: gem install kumi-parser"
          return false
        rescue StandardError => e
          puts "Parse error: #{e.message}"
          return false
        end

        # Run analyzer
        runner_opts = opts.slice(:trace, :snap, :snap_dir, :resume_from, :resume_at, :stop_after)
        res = Dev::Runner.run(schema, runner_opts)

        unless res.ok?
          puts "Analysis errors:"
          res.errors.each { |err| puts "  #{err}" }
          return false
        end

        unless res.ir
          puts "Error: No IR generated"
          return false
        end

        # Report trace file if enabled
        puts "Trace written to: #{res.trace_file}" if opts[:trace] && res.respond_to?(:trace_file)

        # Determine file extension and renderer
        extension = opts[:json] ? "json" : "txt"

        file_name = File.basename(schema_path)
        golden_path = File.join(File.dirname(schema_path), "expected", "#{file_name}_ir.#{extension}")

        # Render IR
        rendered = if opts[:json]
                     Dev::IR.to_json(res.ir, pretty: true)
                   else
                     Dev::IR.to_text(res.ir)
                   end

        # Handle write mode
        if opts[:write]
          FileUtils.mkdir_p(File.dirname(golden_path))
          File.write(golden_path, rendered)
          puts "Wrote: #{golden_path}"
          return true
        end

        # Handle update mode (write only if different)
        if opts[:update]
          if File.exist?(golden_path) && File.read(golden_path) == rendered
            puts "No changes (#{golden_path})"
            return true
          else
            FileUtils.mkdir_p(File.dirname(golden_path))
            File.write(golden_path, rendered)
            puts "Updated: #{golden_path}"
            return true
          end
        end

        # Handle no-diff mode
        if opts[:no_diff]
          puts rendered
          return true
        end

        # Default: diff mode (same as write but show diff instead)
        if File.exist?(golden_path)
          # Use diff directly with the golden file path
          require "tempfile"
          Tempfile.create(["actual", File.extname(golden_path)]) do |actual_file|
            actual_file.write(rendered)
            actual_file.flush

            result = `diff -u --label=expected --label=actual #{golden_path} #{actual_file.path}`
            if result.empty?
              puts "No changes (#{golden_path})"
              return true
            else
              puts result.chomp
              return false
            end
          end
        else
          # No golden file exists, just print the output
          puts rendered
          true
        end
      end
    end
  end
end
