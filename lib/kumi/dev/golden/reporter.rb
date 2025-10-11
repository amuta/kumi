# frozen_string_literal: true

module Kumi
  module Dev
    module Golden
      class Reporter
        def report_update(results_by_schema)
          changed_any = false
          changed_schemas = []
          errors = []

          results_by_schema.each do |schema_name, results|
            schema_changed = false

            results.each do |result|
              if result.changed?
                puts "  #{schema_name}/#{result.representation}.* (#{result.status})"
                schema_changed = true
                changed_any = true
              elsif result.error?
                errors << "  ✗ #{schema_name}/#{result.representation} (error: #{result.error})"
              end
            end

            changed_schemas << schema_name if schema_changed
          end

          if errors.any?
            puts
            errors.each { |e| puts e }
          end

          if changed_any
            puts
            puts "Updated #{changed_schemas.size} schema(s)"
          else
            puts "All schemas up to date"
          end
        end

        def report_verify(results_by_schema)
          success = true

          results_by_schema.each do |schema_name, results|
            failed_reprs = results.select { |r| !r.passed? }

            if failed_reprs.empty?
              puts "✓ #{schema_name}"
            else
              success = false
              failed_msgs = failed_reprs.map do |r|
                case r.status
                when :missing_expected
                  "#{r.representation}.* (no expected file)"
                when :missing_actual
                  "#{r.representation}.* (no actual file)"
                when :error
                  "#{r.representation}.* (error: #{r.error})"
                else
                  "#{r.representation}.*"
                end
              end
              puts "✗ #{schema_name} (#{failed_msgs.join(', ')})"
            end
          end

          success
        end

        def report_diff(results_by_schema)
          results_by_schema.each do |schema_name, results|
            results.each do |result|
              if result.failed? && result.diff
                puts "=== #{schema_name}/#{result.representation}.* ==="
                puts result.diff
                puts
              end
            end
          end
        end

        def report_runtime_tests(results_by_language)
          success = true

          # Organize results by schema
          results_by_schema = {}
          results_by_language.each do |language, schema_results|
            schema_results.each do |result|
              results_by_schema[result.schema_name] ||= {}
              results_by_schema[result.schema_name][language] = result
            end
          end

          # Report failures first
          failed_schemas = results_by_schema.select do |_, lang_results|
            lang_results.values.any? { |r| r.error || !r.passed? }
          end

          if failed_schemas.any?
            puts "Failures:"
            failed_schemas.each do |schema_name, lang_results|
              lang_results.each do |language, result|
                if result.error
                  puts "  ✗ #{schema_name} [#{language}]: #{result.error}"
                  success = false
                elsif !result.passed?
                  puts "  ✗ #{schema_name} [#{language}]: #{result.passed_count}/#{result.total_count} passed"
                  success = false

                  result.test_results.select(&:failed?).each do |test|
                    puts "      #{test.decl_name}: got #{test.actual.inspect}, expected #{test.expected.inspect}"
                  end
                end
              end
            end
            puts
          end

          # Print summary
          print_combined_summary(results_by_language)

          success
        end

        private

        def print_combined_summary(results_by_language)
          stats = {}

          results_by_language.each do |language, schema_results|
            total_tests = 0
            passed_tests = 0
            schema_count = schema_results.size

            schema_results.each do |result|
              total_tests += result.total_count
              passed_tests += result.passed_count
            end

            stats[language] = {
              schemas: schema_count,
              total: total_tests,
              passed: passed_tests,
              failed: total_tests - passed_tests
            }
          end

          # Print combined summary
          languages = stats.keys.sort
          puts "Summary:"
          languages.each do |language|
            s = stats[language]
            status = s[:failed] == 0 ? "✓" : "✗"
            puts "  #{status} #{language}: #{s[:passed]}/#{s[:total]} passed across #{s[:schemas]} schemas"
          end
        end
      end
    end
  end
end
