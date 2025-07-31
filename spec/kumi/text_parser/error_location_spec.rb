# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Text Parser: Error Location Tracking" do
  describe "location tracking in error messages" do
    it "reports correct location for invalid input type" do
      invalid_text = <<~KUMI
        schema do
          input do
            unknown_type :field
          end
        end
      KUMI

      expect do
        Kumi::TextParser.parse(invalid_text, source_file: "test_schema.kumi")
      end.to raise_error(Kumi::Errors::SyntaxError) do |error|
        expect(error.message).to include("Unknown type 'unknown_type'")
        expect(error.message).to include("test_schema.kumi:3")
      end
    end

    it "reports correct location for invalid value syntax" do
      invalid_text = <<~KUMI
        schema do
          input do
            integer :age
          end
          value
        end
      KUMI

      expect do
        Kumi::TextParser.parse(invalid_text, source_file: "test_schema.kumi")
      end.to raise_error(Kumi::Errors::SyntaxError) do |error|
        expect(error.message).to include("Invalid value declaration")
        expect(error.message).to include("test_schema.kumi:5")
      end
    end

    it "reports correct location for missing schema declaration" do
      invalid_text = <<~KUMI
        input do
          integer :age
        end
      KUMI

      expect do
        Kumi::TextParser.parse(invalid_text, source_file: "test_schema.kumi")
      end.to raise_error(Kumi::Errors::SyntaxError) do |error|
        expect(error.message).to include("Missing 'schema do' declaration")
        expect(error.message).to include("test_schema.kumi:1")
      end
    end
  end

  describe "AST nodes include location information" do
    it "includes location in input declarations" do
      text_dsl = <<~KUMI
        schema do
          input do
            integer :age
            string :name
          end
        end
      KUMI

      ast = Kumi::TextParser.parse(text_dsl, source_file: "test.kumi")
      
      expect(ast.inputs.length).to eq(2)
      
      age_input = ast.inputs[0]
      name_input = ast.inputs[1]
      
      expect(age_input.loc.file).to eq("test.kumi")
      expect(age_input.loc.line).to eq(3)
      
      expect(name_input.loc.file).to eq("test.kumi")
      expect(name_input.loc.line).to eq(4)
    end

    it "includes location in value declarations" do
      text_dsl = <<~KUMI
        schema do
          input do
            integer :a
            integer :b
          end
          value :sum, input.a + input.b
          value :product, input.a * input.b
        end
      KUMI

      ast = Kumi::TextParser.parse(text_dsl, source_file: "test.kumi")
      
      expect(ast.attributes.length).to eq(2)
      
      sum_value = ast.attributes[0]
      product_value = ast.attributes[1]
      
      expect(sum_value.loc.file).to eq("test.kumi")
      expect(sum_value.loc.line).to eq(6)
      
      expect(product_value.loc.file).to eq("test.kumi") 
      expect(product_value.loc.line).to eq(7)
    end
  end
end