# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kumi::Export do
  include ASTFactory

  describe ".to_json" do
    it "exports a simple schema to JSON" do
      # Build a simple schema AST
      inputs = [field_decl(:name, type: :string)]
      attributes = [attr(:greeting, field_ref(:name))]
      traits = []

      syntax_root = syntax(:root, inputs, attributes, traits)

      json_string = described_class.to_json(syntax_root)

      expect(json_string).to be_a(String)
      expect { JSON.parse(json_string) }.not_to raise_error
    end

    it "exports with pretty formatting when requested" do
      inputs = [field_decl(:age, type: :integer)]
      attributes = []
      traits = [trait(:adult, call(:>=, field_ref(:age), lit(18)))]

      syntax_root = syntax(:root, inputs, attributes, traits)

      json_string = described_class.to_json(syntax_root, pretty: true)

      expect(json_string).to include("\n")
      expect(json_string).to include("  ")
    end
  end

  describe ".from_json" do
    it "imports a simple schema from JSON" do
      # Create original AST
      inputs = [field_decl(:name, type: :string)]
      attributes = [attr(:greeting, field_ref(:name))]
      traits = []

      original_ast = syntax(:root, inputs, attributes, traits)

      # Export and import
      json_string = described_class.to_json(original_ast)
      imported_ast = described_class.from_json(json_string)

      expect(imported_ast).to be_a(Kumi::Syntax::Root)
      expect(imported_ast.inputs.size).to eq(1)
      expect(imported_ast.attributes.size).to eq(1)
      expect(imported_ast.traits.size).to eq(0)
    end
  end

  describe "round-trip preservation" do
    it "preserves simple schemas" do
      # Build a simple but complete schema
      inputs = [
        field_decl(:name, type: :string),
        field_decl(:age, type: :integer)
      ]

      attributes = [
        attr(:greeting, call(:concat, lit("Hello, "), field_ref(:name)))
      ]

      traits = [
        trait(:adult, call(:>=, field_ref(:age), lit(18)))
      ]

      original_ast = syntax(:root, inputs, attributes, traits)

      # Round-trip
      json_string = described_class.to_json(original_ast)
      imported_ast = described_class.from_json(json_string)

      # Verify structure preservation
      expect(imported_ast.inputs.size).to eq(original_ast.inputs.size)
      expect(imported_ast.attributes.size).to eq(original_ast.attributes.size)
      expect(imported_ast.traits.size).to eq(original_ast.traits.size)

      # Verify field names are preserved
      expect(imported_ast.inputs.first.name).to eq(:name)
      expect(imported_ast.attributes.first.name).to eq(:greeting)
      expect(imported_ast.traits.first.name).to eq(:adult)
    end
  end

  describe ".valid?" do
    it "returns true for valid JSON" do
      inputs = [field_decl(:test, type: :string)]
      syntax_root = syntax(:root, inputs, [], [])
      json_string = described_class.to_json(syntax_root)

      expect(described_class.valid?(json_string)).to be true
    end

    it "returns false for invalid JSON" do
      expect(described_class.valid?("invalid json")).to be false
      expect(described_class.valid?("{}")).to be false
    end
  end
end
