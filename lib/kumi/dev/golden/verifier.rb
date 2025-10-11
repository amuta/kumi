# frozen_string_literal: true

module Kumi
  module Dev
    module Golden
      class Verifier
        attr_reader :schema_name, :expected_dir, :actual_dir

        def initialize(schema_name, expected_dir, actual_dir)
          @schema_name = schema_name
          @expected_dir = expected_dir
          @actual_dir = actual_dir
        end

        def verify_all(representations)
          representations.map do |repr|
            verify_representation(repr)
          end
        end

        private

        def verify_representation(repr)
          expected_file = File.join(expected_dir, repr.filename)
          actual_file = File.join(actual_dir, repr.filename)

          unless File.exist?(expected_file)
            return VerificationResult.new(
              schema_name: schema_name,
              representation: repr.name,
              status: :missing_expected
            )
          end

          unless File.exist?(actual_file)
            return VerificationResult.new(
              schema_name: schema_name,
              representation: repr.name,
              status: :missing_actual
            )
          end

          expected_content = File.read(expected_file)
          actual_content = File.read(actual_file)

          if expected_content.strip == actual_content.strip
            VerificationResult.new(
              schema_name: schema_name,
              representation: repr.name,
              status: :passed
            )
          else
            VerificationResult.new(
              schema_name: schema_name,
              representation: repr.name,
              status: :failed,
              diff: compute_diff(expected_file, actual_file)
            )
          end
        rescue StandardError => e
          VerificationResult.new(
            schema_name: schema_name,
            representation: repr.name,
            status: :error,
            error: e.message
          )
        end

        def compute_diff(expected_file, actual_file)
          output, status = Open3.capture2("diff", "-u", expected_file, actual_file)
          status.success? ? nil : output
        end
      end
    end
  end
end
