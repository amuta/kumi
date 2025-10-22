# frozen_string_literal: true

module Kumi
  module Dev
    module Golden
      class Suite
        attr_reader :base_dir, :representations

        def initialize(base_dir: "golden", representations: REPRESENTATIONS)
          @base_dir = base_dir
          @representations = representations
          # Ensure shared schemas are loaded for imports
          ensure_golden_schemas_loaded!
        end

        def list
          schema_names.each { |name| puts name }
        end

        def update(name = nil)
          names = if name
                    name.is_a?(Array) ? name : [name]
                  else
                    schema_names
                  end
          results = update_schemas(names)
          Reporter.new.report_update(results)
        end

        def verify(name = nil)
          names = if name
                    name.is_a?(Array) ? name : [name]
                  else
                    schema_names
                  end
          results = verify_schemas(names)
          Reporter.new.report_verify(results)
        end

        def diff(name = nil)
          names = if name
                    name.is_a?(Array) ? name : [name]
                  else
                    schema_names
                  end
          results = diff_schemas(names)
          Reporter.new.report_diff(results)
        end

        def test(name = nil)
          names = if name
                    name.is_a?(Array) ? name : [name]
                  else
                    schema_names
                  end

          update_schemas(names)

          ruby_results = run_runtime_tests(names, :ruby)
          js_results = run_runtime_tests(names, :javascript)

          Reporter.new.report_runtime_tests(
            ruby: ruby_results,
            javascript: js_results
          )
        end

        private

        def ensure_golden_schemas_loaded!
          shared_dir = File.expand_path("../../../golden/_shared", __dir__)
          return unless File.directory?(shared_dir)
          Dir.glob("#{shared_dir}/*.rb").sort.each { |f| require f }
        end

        def schema_names
          Dir.glob(File.join(base_dir, "*/schema.kumi"))
             .map { |path| File.basename(File.dirname(path)) }
             .sort
        end

        def schema_path(name)
          File.join(base_dir, name, "schema.kumi")
        end

        def expected_dir(name)
          File.join(base_dir, name, "expected")
        end

        def tmp_dir(name)
          File.join(base_dir, name, "tmp")
        end

        def schema_dir(name)
          File.join(base_dir, name)
        end

        def update_schemas(names)
          names.each_with_object({}) do |name, results|
            path = schema_path(name)
            unless File.exist?(path)
              puts "Warning: #{path} not found, skipping"
              next
            end

            generator = Generator.new(name, path, expected_dir(name))
            results[name] = generator.update_all(representations)
          end
        end

        def verify_schemas(names)
          names.each_with_object({}) do |name, results|
            path = schema_path(name)
            unless File.exist?(path)
              puts "Warning: #{path} not found, skipping"
              next
            end

            generator = Generator.new(name, path, tmp_dir(name))
            generator.generate_all(representations, tmp_dir(name))

            verifier = Verifier.new(name, expected_dir(name), tmp_dir(name))
            results[name] = verifier.verify_all(representations)
          end
        end

        def diff_schemas(names)
          names.each_with_object({}) do |name, results|
            verifier = Verifier.new(name, expected_dir(name), tmp_dir(name))
            results[name] = verifier.verify_all(representations)
          end
        end

        def run_runtime_tests(names, language)
          testable_names = filter_testable_schemas(names, language)

          testable_names.map do |name|
            RuntimeTest.new(name, language).run(schema_dir(name))
          end
        end

        def filter_testable_schemas(names, language)
          extension = language == :ruby ? "rb" : "mjs"
          code_filename = "expected/schema_#{language}.#{extension}"

          names.select do |name|
            File.exist?(File.join(schema_dir(name), code_filename)) &&
              File.exist?(File.join(schema_dir(name), "input.json")) &&
              File.exist?(File.join(schema_dir(name), "expected.json"))
          end
        end
      end
    end
  end
end
