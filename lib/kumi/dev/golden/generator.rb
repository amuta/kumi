# frozen_string_literal: true

require "fileutils"

module Kumi
  module Dev
    module Golden
      class Generator
        attr_reader :schema_name, :schema_path, :expected_dir

        def initialize(schema_name, schema_path, expected_dir)
          @schema_name = schema_name
          @schema_path = schema_path
          @expected_dir = expected_dir
        end

        def update_all(representations)
          FileUtils.mkdir_p(expected_dir)

          representations.map do |repr|
            update_representation(repr)
          end
        end

        def generate_all(representations, output_dir)
          FileUtils.mkdir_p(output_dir)

          representations.map do |repr|
            generate_representation(repr, output_dir)
          end
        end

        private

        def update_representation(repr)
          output = generate_output(repr)
          unless output
            return GenerationResult.new(
              schema_name: schema_name,
              representation: repr.name,
              status: :skipped
            )
          end

          expected_file = File.join(expected_dir, repr.filename)

          if File.exist?(expected_file)
            expected_content = File.read(expected_file)
            if output.strip == expected_content.strip
              return GenerationResult.new(
                schema_name: schema_name,
                representation: repr.name,
                status: :unchanged
              )
            end
          end

          File.write(expected_file, output)
          status = File.exist?(expected_file) && File.read(expected_file).strip != output.strip ? :created : :updated

          GenerationResult.new(
            schema_name: schema_name,
            representation: repr.name,
            status: status,
            changed: true
          )
        rescue StandardError => e
          GenerationResult.new(
            schema_name: schema_name,
            representation: repr.name,
            status: :error,
            error: e.message
          )
        end

        def generate_representation(repr, output_dir)
          output = generate_output(repr)
          unless output
            return GenerationResult.new(
              schema_name: schema_name,
              representation: repr.name,
              status: :skipped
            )
          end

          output_file = File.join(output_dir, repr.filename)
          File.write(output_file, output)

          GenerationResult.new(
            schema_name: schema_name,
            representation: repr.name,
            status: :generated
          )
        rescue StandardError => e
          GenerationResult.new(
            schema_name: schema_name,
            representation: repr.name,
            status: :error,
            error: e.message
          )
        end

        def generate_output(repr)
          repr.generate(schema_path)
        end
      end
    end
  end
end
