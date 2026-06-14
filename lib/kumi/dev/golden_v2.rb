# frozen_string_literal: true

require "fileutils"
require "tempfile"

module Kumi
  module Dev
    module GoldenV2
      # Precompile shared schemas so their syntax trees are available to import
      # goldens (their JS needs the generated shared modules). No-op when the
      # shared schemas aren't loaded.
      def self.precompile_schemas!
        return unless defined?(Kumi::TestSharedSchemas)

        Kumi::TestSharedSchemas.constants.each do |const|
          mod = Kumi::TestSharedSchemas.const_get(const)
          mod.runner if mod.is_a?(Module) && mod.respond_to?(:runner)
        end
      end

      Representation = Struct.new(:name, :extension, :generator_method, keyword_init: true) do
        def filename
          "#{name}.#{extension}"
        end

        def generate(schema_path)
          raise "Unknown generator method: #{generator_method}" unless PrettyPrinter.respond_to?(generator_method)

          PrettyPrinter.public_send(generator_method, schema_path)
        end
      end

      REPRESENTATIONS = [
        Representation.new(name: "ast", extension: "txt", generator_method: :generate_ast),
        Representation.new(name: "input_plan", extension: "txt", generator_method: :generate_input_plan),
        Representation.new(name: "nast", extension: "txt", generator_method: :generate_nast),
        Representation.new(name: "snast", extension: "txt", generator_method: :generate_snast),
        Representation.new(name: "dfir", extension: "txt", generator_method: :generate_dfir),
        Representation.new(name: "dfir_optimized", extension: "txt", generator_method: :generate_dfir_optimized),
        Representation.new(name: "vecir", extension: "txt", generator_method: :generate_vecir),
        Representation.new(name: "loopir", extension: "txt", generator_method: :generate_loopir),
        Representation.new(name: "schema_ruby", extension: "rb", generator_method: :generate_schema_ruby),
        Representation.new(name: "schema_javascript", extension: "mjs", generator_method: :generate_schema_javascript),
        # Executes the generated Ruby + JS against input.json, snapshots the
        # outputs, and asserts Ruby == JS. No-ops (nil) for schemas without an
        # input.json. This is the runtime + bit-identical-parity coverage.
        Representation.new(name: "runtime", extension: "json", generator_method: :generate_runtime)
      ].freeze

      GROUPS = {
        "frontend" => %w[ast input_plan nast snast],
        "df" => %w[dfir dfir_optimized],
        "vec" => %w[vecir],
        "loop" => %w[loopir],
        "codegen" => %w[schema_ruby schema_javascript],
        "runtime" => %w[runtime],
        "all" => REPRESENTATIONS.map(&:name)
      }.freeze

      module_function

      def list(base_dir: "golden", io: $stdout)
        Runner.new(base_dir:, io:).list_schemas
      end

      def reprs(io: $stdout)
        Runner.new(io:).list_representations
      end

      def update!(*names, reprs: nil, base_dir: "golden", io: $stdout)
        Runner.new(base_dir:, io:).update(names: normalize_names(names), reprs:)
      end

      def verify!(*names, reprs: nil, base_dir: "golden", io: $stdout)
        Runner.new(base_dir:, io:).verify(names: normalize_names(names), reprs:)
      end

      def diff!(*names, reprs: nil, base_dir: "golden", io: $stdout)
        Runner.new(base_dir:, io:).diff(names: normalize_names(names), reprs:)
      end

      def normalize_repr_tokens(raw)
        Array(raw)
          .flat_map { |entry| entry.to_s.split(",") }
          .map(&:strip)
          .reject(&:empty?)
      end

      def normalize_names(raw)
        names = Array(raw).flatten.compact.map(&:to_s).reject(&:empty?)
        names.empty? ? nil : names
      end

      class Runner
        attr_reader :base_dir, :io

        def initialize(base_dir: "golden", io: $stdout)
          @base_dir = base_dir
          @io = io
        end

        def list_schemas
          schema_names.each { |name| io.puts(name) }
        end

        def list_representations
          io.puts "Representations:"
          representation_names.each { |name| io.puts("  #{name}") }
          io.puts
          io.puts "Groups:"
          GROUPS.each do |name, members|
            io.puts("  #{name}=#{members.join(',')}")
          end
        end

        def update(names:, reprs:)
          any_changed = false
          any_error = false

          each_schema(names) do |schema_name, schema_path|
            expected_dir = File.join(base_dir, schema_name, "expected")
            FileUtils.mkdir_p(expected_dir)

            each_representation(reprs) do |repr|
              result = generate(repr, schema_path)
              if result[:status] == :error
                any_error = true
                io.puts("✗ #{schema_name}/#{repr.filename} (error: #{result[:error]})")
                next
              end

              next if result[:output].nil?

              expected_file = File.join(expected_dir, repr.filename)
              old = File.exist?(expected_file) ? File.read(expected_file) : nil

              if old && normalize(old) == normalize(result[:output])
                io.puts("= #{schema_name}/#{repr.filename}")
                next
              end

              File.write(expected_file, result[:output])
              any_changed = true
              label = old.nil? ? "created" : "updated"
              io.puts("#{label == 'created' ? '+' : '~'} #{schema_name}/#{repr.filename} (#{label})")
            end
          end

          io.puts(any_changed ? "Updated golden files" : "No golden changes")
          !any_error
        end

        def verify(names:, reprs:)
          success = true

          each_schema(names) do |schema_name, schema_path|
            failures = []

            each_representation(reprs) do |repr|
              result = verify_representation(schema_name, schema_path, repr)
              failures << result unless %i[passed skipped].include?(result[:status])
            end

            if failures.empty?
              io.puts("✓ #{schema_name}")
            else
              success = false
              summary = failures.map { format_failure(_1) }.join(", ")
              io.puts("✗ #{schema_name} (#{summary})")
            end
          end

          success
        end

        def diff(names:, reprs:)
          success = true

          each_schema(names) do |schema_name, schema_path|
            each_representation(reprs) do |repr|
              result = verify_representation(schema_name, schema_path, repr)
              next if result[:status] == :passed

              success = false
              io.puts("=== #{schema_name}/#{repr.filename} (#{result[:status]}) ===")
              if result[:diff]
                io.puts(result[:diff])
              elsif result[:error]
                io.puts(result[:error])
              else
                io.puts(format_failure(result))
              end
              io.puts
            end
          end

          success
        end

        def select_representations(tokens)
          selected = GoldenV2.normalize_repr_tokens(tokens)
          selected = ["all"] if selected.empty?

          names = selected.flat_map do |token|
            GROUPS.fetch(token, [token])
          end

          known = representations_by_name
          unknown = names.uniq.reject { |name| known.key?(name) }
          raise ArgumentError, "unknown representations: #{unknown.join(', ')}" if unknown.any?

          names.uniq.map { |name| known.fetch(name) }
        end

        private

        def representation_names
          REPRESENTATIONS.map(&:name)
        end

        def representations_by_name
          @representations_by_name ||= REPRESENTATIONS.each_with_object({}) do |repr, acc|
            acc[repr.name] = repr
          end
        end

        def each_schema(names)
          targets = names || schema_names
          targets.each do |schema_name|
            schema_path = File.join(base_dir, schema_name, "schema.kumi")
            unless File.exist?(schema_path)
              io.puts("! missing schema: #{schema_path}")
              next
            end

            yield schema_name, schema_path
          end
        end

        def each_representation(tokens, &)
          select_representations(tokens).each(&)
        end

        def schema_names
          Dir.glob(File.join(base_dir, "*/schema.kumi"))
             .map { |path| File.basename(File.dirname(path)) }
             .sort
        end

        def verify_representation(schema_name, schema_path, repr)
          expected_file = File.join(base_dir, schema_name, "expected", repr.filename)
          actual = generate(repr, schema_path)
          return actual.merge(repr:) if actual[:status] == :error

          unless File.exist?(expected_file)
            # A representation that legitimately produces no output for this
            # schema (e.g. `runtime` with no input.json) is not a failure — it
            # simply doesn't apply. Only flag a missing expected file when the
            # generator actually produced output that should have been recorded.
            return { status: :skipped, repr: } if actual[:output].nil?

            return { status: :missing_expected, repr: }
          end

          return { status: :missing_actual, repr: } if actual[:output].nil?

          expected = File.read(expected_file)
          return { status: :passed, repr: } if normalize(expected) == normalize(actual[:output])

          {
            status: :failed,
            repr:,
            diff: unified_diff(expected, actual[:output], expected_file, repr.filename)
          }
        end

        def generate(repr, schema_path)
          { status: :ok, output: repr.generate(schema_path) }
        rescue StandardError => e
          { status: :error, error: e.message }
        end

        def format_failure(result)
          case result[:status]
          when :missing_expected
            "#{result[:repr].filename} (no expected file)"
          when :missing_actual
            "#{result[:repr].filename} (no actual output)"
          when :error
            "#{result[:repr].filename} (error: #{result[:error]})"
          when :failed
            result[:repr].filename
          else
            "#{result[:repr].filename} (#{result[:status]})"
          end
        end

        def unified_diff(expected, actual, expected_label, actual_label)
          Tempfile.create("golden_v2_expected") do |expected_file|
            Tempfile.create("golden_v2_actual") do |actual_file|
              expected_file.write(expected)
              expected_file.flush
              actual_file.write(actual)
              actual_file.flush

              `diff -u --label=#{expected_label} --label=#{actual_label} #{expected_file.path} #{actual_file.path}`
            end
          end
        end

        def normalize(text)
          text.to_s.strip
        end
      end
    end
  end
end
