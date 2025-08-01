# frozen_string_literal: true

require "tmpdir"

RSpec.describe Kumi::Core::Export do
  include ASTFactory

  describe ".to_json" do
    it "exports a simple schema to JSON" do
      # Build a simple schema AST
      inputs = [input_decl(:name, :string)]
      attributes = [attr(:greeting, field_ref(:name))]
      traits = []

      syntax_root = syntax(:root, inputs, attributes, traits)

      json_string = described_class.to_json(syntax_root)

      expect(json_string).to be_a(String)
      expect { JSON.parse(json_string) }.not_to raise_error
    end

    it "exports with pretty formatting when requested" do
      inputs = [input_decl(:age, :integer)]
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
      inputs = [input_decl(:name, :string)]
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
        input_decl(:name, :string),
        input_decl(:age, :integer)
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

  describe ".to_file" do
    it "writes schema to file" do
      inputs = [input_decl(:name, :string)]
      syntax_root = syntax(:root, inputs, [], [])

      Dir.mktmpdir do |dir|
        filepath = File.join(dir, "schema.json")

        described_class.to_file(syntax_root, filepath)

        expect(File.exist?(filepath)).to be true
        expect(File.read(filepath)).to include('"name"')
      end
    end

    it "writes pretty formatted JSON when requested" do
      inputs = [input_decl(:age, :integer)]
      syntax_root = syntax(:root, inputs, [], [])

      Dir.mktmpdir do |dir|
        filepath = File.join(dir, "pretty_schema.json")

        described_class.to_file(syntax_root, filepath, pretty: true)

        content = File.read(filepath)
        expect(content).to include("\n")
        expect(content).to include("  ")
      end
    end
  end

  describe ".from_file" do
    it "reads schema from file" do
      inputs = [input_decl(:name, :string)]
      attributes = [attr(:greeting, field_ref(:name))]
      original_ast = syntax(:root, inputs, attributes, [])

      Dir.mktmpdir do |dir|
        filepath = File.join(dir, "schema.json")

        described_class.to_file(original_ast, filepath)
        imported_ast = described_class.from_file(filepath)

        expect(imported_ast).to be_a(Kumi::Syntax::Root)
        expect(imported_ast.inputs.size).to eq(1)
        expect(imported_ast.attributes.size).to eq(1)
        expect(imported_ast.inputs.first.name).to eq(:name)
      end
    end

    it "raises error for non-existent file" do
      expect do
        described_class.from_file("/nonexistent/file.json")
      end.to raise_error(Errno::ENOENT)
    end
  end

  describe "serializer options" do
    it "exports with location information when requested" do
      inputs = [input_decl(:name, :string)]
      syntax_root = syntax(:root, inputs, [], [])

      json_string = described_class.to_json(syntax_root, include_locations: true)

      expect(json_string).to be_a(String)
      parsed_json = JSON.parse(json_string)
      expect(parsed_json).to have_key("kumi_version")
      expect(parsed_json).to have_key("ast")
    end

    it "exports compact JSON by default" do
      inputs = [input_decl(:name, :string)]
      syntax_root = syntax(:root, inputs, [], [])

      json_string = described_class.to_json(syntax_root)

      expect(json_string).not_to include("\n")
      expect(json_string).not_to include("  ")
    end
  end

  describe "deserializer options" do
    it "validates JSON structure by default" do
      invalid_json = '{"invalid": "structure"}'

      expect do
        described_class.from_json(invalid_json)
      end.to raise_error(Kumi::Core::Export::Errors::DeserializationError, /Missing required fields/)
    end

    it "skips validation when requested" do
      inputs = [input_decl(:name, :string)]
      syntax_root = syntax(:root, inputs, [], [])

      json_string = described_class.to_json(syntax_root)

      expect do
        described_class.from_json(json_string, validate: false)
      end.not_to raise_error
    end

    it "validates root node type" do
      invalid_root_json = JSON.generate({
                                          kumi_version: Kumi::VERSION,
                                          ast: { type: "not_root", inputs: [], attributes: [], traits: [] }
                                        })

      expect do
        described_class.from_json(invalid_root_json)
      end.to raise_error(Kumi::Core::Export::Errors::DeserializationError, /Root node must have type 'root'/)
    end
  end

  describe "error handling" do
    it "raises DeserializationError for malformed JSON" do
      expect do
        described_class.from_json("{ invalid json")
      end.to raise_error(Kumi::Core::Export::Errors::DeserializationError, /Invalid JSON/)
    end

    it "handles file write errors gracefully" do
      inputs = [input_decl(:name, :string)]
      syntax_root = syntax(:root, inputs, [], [])

      expect do
        described_class.to_file(syntax_root, "/invalid/path/file.json")
      end.to raise_error(Errno::ENOENT)
    end

    it "handles file read errors gracefully" do
      expect do
        described_class.from_file("/invalid/path/file.json")
      end.to raise_error(Errno::ENOENT)
    end
  end

  describe ".valid?" do
    it "returns true for valid JSON" do
      inputs = [input_decl(:test, :string)]
      syntax_root = syntax(:root, inputs, [], [])
      json_string = described_class.to_json(syntax_root)

      expect(described_class.valid?(json_string)).to be true
    end

    it "returns false for invalid JSON" do
      expect(described_class.valid?("invalid json")).to be false
      expect(described_class.valid?("{}")).to be false
    end

    it "returns false for JSON parse errors" do
      expect(described_class.valid?("{ invalid")).to be false
    end

    it "returns false for deserialization errors" do
      malformed_kumi_json = JSON.generate({ wrong: "structure" })
      expect(described_class.valid?(malformed_kumi_json)).to be false
    end
  end
end
