# frozen_string_literal: true

RSpec.describe Kumi::JsonSchema::Generator do
  subject(:generator) { described_class.new(mock_metadata) }

  let(:mock_metadata) do
    double("metadata",
           inputs: {
             name: { type: :string, required: true, domain: { type: :enum, values: %w[alice bob] } },
             age: { type: :integer, required: true, domain: { type: :range, min: 0, max: 150, exclusive_end: false } }
           },
           values: {
             greeting: { type: :string, computed: true, expression: "Hello input.name" }
           },
           traits: {
             adult: { type: :boolean, condition: "input.age >= 18" }
           })
  end

  describe "#generate" do
    let(:schema) { generator.generate }

    it "generates a valid JSON Schema structure" do
      expect(schema[:type]).to eq("object")
      expect(schema[:properties]).to be_a(Hash)
      expect(schema[:required]).to be_an(Array)
    end

    it "converts input types correctly" do
      properties = schema[:properties]

      expect(properties[:name]).to include(
        type: "string",
        enum: %w[alice bob]
      )

      expect(properties[:age]).to include(
        type: "integer",
        minimum: 0,
        maximum: 150
      )
    end

    it "includes required fields" do
      expect(schema[:required]).to contain_exactly(:name, :age)
    end

    it "includes Kumi-specific extensions" do
      expect(schema[:"x-kumi-values"]).to eq(mock_metadata.values)
      expect(schema[:"x-kumi-traits"]).to eq(mock_metadata.traits)
    end
  end

  describe "type mapping" do
    subject(:generator) { described_class.new(mock_metadata) }

    it "maps Kumi types to JSON Schema types" do
      # Access private method for testing
      expect(generator.send(:map_kumi_type_to_json_schema, :string)).to eq("string")
      expect(generator.send(:map_kumi_type_to_json_schema, :integer)).to eq("integer")
      expect(generator.send(:map_kumi_type_to_json_schema, :float)).to eq("number")
      expect(generator.send(:map_kumi_type_to_json_schema, :boolean)).to eq("boolean")
      expect(generator.send(:map_kumi_type_to_json_schema, :array)).to eq("array")
      expect(generator.send(:map_kumi_type_to_json_schema, :hash)).to eq("object")
      expect(generator.send(:map_kumi_type_to_json_schema, :unknown)).to eq("string")
    end
  end
end
