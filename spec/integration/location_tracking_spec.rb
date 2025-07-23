# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Location Tracking Accuracy" do
  describe "syntax error location reporting" do
    let(:fixture_path) { File.join(__dir__, "..", "fixtures", "location_tracking_test_schema.rb") }
    let(:fixture_content) { File.read(fixture_path) }

    context "when parsing schema with syntax errors" do
      it "reports accurate location for invalid value name syntax" do
        expect do
          load fixture_path
        end.to raise_error(Kumi::Errors::SyntaxError) do |error|
          expect(error.message).to include("The name for 'value' must be a Symbol, got Array")
          expect(error.location.file).to end_with("location_tracking_test_schema.rb")
          expect(error.location.line).to eq(16) # Line with "value value :bad_name, 42"
        end
      end
    end

    context "when encountering different error types" do
      it "accurately reports location for invalid value name (Array instead of Symbol)" do
        temp_schema_content = create_schema_with_single_error("value value :bad_name, 42", 15)
        temp_file = write_temp_schema(temp_schema_content)

        begin
          expect do
            load temp_file
          end.to raise_error(Kumi::Errors::SyntaxError) do |error|
            expect(error.message).to include("The name for 'value' must be a Symbol, got Array")
            expect(error.location.file).to eq(temp_file)
            expect(error.location.line).to eq(15)
          end
        ensure
          FileUtils.rm_f(temp_file)
        end
      end

      it "accurately reports location for invalid trait name (String instead of Symbol)" do
        temp_schema_content = create_schema_with_single_error('trait "bad_trait_name", (input.age >= 18)', 15)
        temp_file = write_temp_schema(temp_schema_content)

        begin
          expect do
            load temp_file
          end.to raise_error(Kumi::Errors::SyntaxError) do |error|
            expect(error.message).to include("The name for 'trait' must be a Symbol, got String")
            expect(error.location.file).to eq(temp_file)
            expect(error.location.line).to eq(15)
          end
        ensure
          FileUtils.rm_f(temp_file)
        end
      end

      it "accurately reports location for missing expression for value" do
        temp_schema_content = create_schema_with_single_error("value :incomplete_value", 15)
        temp_file = write_temp_schema(temp_schema_content)

        begin
          expect do
            load temp_file
          end.to raise_error(Kumi::Errors::SyntaxError) do |error|
            expect(error.message).to include("value 'incomplete_value' requires an expression or a block")
            expect(error.location.file).to eq(temp_file)
            expect(error.location.line).to eq(15)
          end
        ensure
          FileUtils.rm_f(temp_file)
        end
      end

      it "accurately reports location for invalid operator in deprecated trait syntax" do
        temp_schema_content = create_schema_with_single_error("trait :bad_operator, input.age, :invalid_op, 18", 15)
        temp_file = write_temp_schema(temp_schema_content)

        begin
          expect do
            load temp_file
          end.to raise_error(Kumi::Errors::SyntaxError) do |error|
            expect(error.message).to include("unsupported operator `invalid_op`")
            expect(error.location.file).to eq(temp_file)
            expect(error.location.line).to eq(15)
          end
        ensure
          FileUtils.rm_f(temp_file)
        end
      end
    end

    context "location tracking precision" do
      it "points to user DSL code, not internal schema_builder.rb" do
        temp_schema = create_simple_error_schema
        temp_file = write_temp_schema(temp_schema)

        begin
          expect do
            load temp_file
          end.to raise_error(Kumi::Errors::SyntaxError) do |error|
            # Should NOT point to internal schema_builder.rb
            expect(error.location.file).not_to include("schema_builder.rb")
            # Should point to the actual user file
            expect(error.location.file).to eq(temp_file)
            # Should have a reasonable line number (not 0 or negative)
            expect(error.location.line).to be > 0
          end
        ensure
          FileUtils.rm_f(temp_file)
        end
      end

      it "maintains location accuracy across multiple DSL method calls" do
        complex_schema = create_complex_error_schema
        temp_file = write_temp_schema(complex_schema)

        begin
          expect do
            load temp_file
          end.to raise_error(Kumi::Errors::SyntaxError) do |error|
            # First error should be the value error on line 8
            expect(error.location.line).to eq(8)
            expect(error.message).to include("The name for 'value' must be a Symbol")
          end
        ensure
          FileUtils.rm_f(temp_file)
        end
      end
    end
  end

  private

  def create_schema_with_single_error(error_line, line_number)
    base_lines = [
      "class TestSchema#{rand(10_000)}",
      "  extend Kumi::Schema",
      "",
      "  schema do",
      "    input do",
      "      integer :age",
      "    end",
      ""
    ]

    # Add enough blank lines to get to the target line number
    base_lines << "" while base_lines.length < line_number - 1

    base_lines << "    #{error_line}"
    base_lines << "  end"
    base_lines << "end"

    base_lines.join("\n")
  end

  def create_simple_error_schema
    <<~RUBY
      class SimpleErrorSchema#{rand(10_000)}
        extend Kumi::Schema

        schema do
          input do
            integer :age
          end
      #{'    '}
          value value :bad_syntax, 42
        end
      end
    RUBY
  end

  def create_complex_error_schema
    <<~RUBY
      class ComplexErrorSchema#{rand(10_000)}
        extend Kumi::Schema

        schema do
          input do
            integer :age
          end
          value value :bad_syntax, 42
          trait :good_trait, (input.age >= 18)
        end
      end
    RUBY
  end

  def write_temp_schema(content)
    temp_file = File.join(Dir.tmpdir, "test_schema_#{rand(100_000)}.rb")
    File.write(temp_file, content)
    temp_file
  end
end
