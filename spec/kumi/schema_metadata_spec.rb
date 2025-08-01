# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kumi::SchemaMetadata do
  let(:test_schema) do
    Class.new do
      extend Kumi::Schema

      schema do
        input do
          float :amount, domain: 0.0..1000.0
          string :type, domain: %w[credit debit]
          integer :count
          any :metadata
        end

        trait :large_amount, (input.amount > 100.0)
        trait :credit_type, (input.type == "credit")

        value :fee do
          on large_amount, fn(:multiply, input.amount, 0.02)
          base 5.0
        end

        value :multiplier, fn(:multiply, input.count, 2)
      end
    end
  end

  let(:metadata) { test_schema.schema_metadata }

  describe "#inputs" do
    it "extracts input field metadata" do
      expect(metadata.inputs[:amount]).to include(
        type: :float,
        domain: { type: :range, min: 0.0, max: 1000.0, exclusive_end: false },
        required: true
      )
    end

    it "handles enum domains" do
      expect(metadata.inputs[:type]).to include(
        type: :string,
        domain: { type: :enum, values: %w[credit debit] },
        required: true
      )
    end

    it "handles fields without domains" do
      expect(metadata.inputs[:count]).to include(
        type: :integer,
        required: true
      )
      expect(metadata.inputs[:count]).not_to have_key(:domain)
    end

    it "handles any type fields" do
      expect(metadata.inputs[:metadata]).to include(
        type: :any,
        required: true
      )
    end
  end

  describe "#values" do
    it "extracts value metadata with dependencies" do
      expect(metadata.values[:fee]).to include(
        type: :float,
        dependencies: contain_exactly(:large_amount, :amount),
        computed: true
      )
    end

    it "extracts simple expression values" do
      expect(metadata.values[:multiplier]).to include(
        type: :float,
        dependencies: [:count],
        computed: true,
        expression: "multiply(input.count, 2)"
      )
    end

    it "extracts cascade information" do
      cascade_info = metadata.values[:fee][:cascade]
      expect(cascade_info).to have_key(:conditions)
      expect(cascade_info[:conditions]).to be_an(Array)
      expect(cascade_info[:conditions]).not_to be_empty
    end
  end

  describe "#traits" do
    it "extracts trait metadata" do
      expect(metadata.traits[:large_amount]).to include(
        type: :boolean,
        dependencies: [:amount],
        condition: ">(input.amount, 100.0)"
      )
    end

    it "extracts trait with string comparison" do
      expect(metadata.traits[:credit_type]).to include(
        type: :boolean,
        dependencies: [:type],
        condition: "==(input.type, \"credit\")"
      )
    end
  end

  describe "#functions" do
    it "extracts function information from registry" do
      functions = metadata.functions
      expect(functions).to have_key(:multiply)
      expect(functions[:multiply]).to include(
        param_types: %i[float float],
        return_type: :float
      )
    end
  end

  describe "#to_h" do
    it "converts metadata to hash" do
      hash = metadata.to_h
      expect(hash).to have_key(:inputs)
      expect(hash).to have_key(:values)
      expect(hash).to have_key(:traits)
      expect(hash).to have_key(:functions)
    end
  end

  describe "#to_json" do
    it "converts to JSON cleanly" do
      json = metadata.to_json
      parsed = JSON.parse(json, symbolize_names: true)

      expect(parsed[:inputs]).not_to be_empty
      expect(parsed[:values]).not_to be_empty
      expect(parsed[:traits]).not_to be_empty
      expect(parsed[:functions]).not_to be_empty
    end
  end

  describe "#to_json_schema" do
    it "generates JSON Schema compatible structure" do
      schema = metadata.to_json_schema

      expect(schema[:type]).to eq("object")
      expect(schema[:required]).to contain_exactly(:amount, :type, :count, :metadata)

      properties = schema[:properties]
      expect(properties[:amount]).to include(
        type: "number",
        minimum: 0.0,
        maximum: 1000.0
      )

      expect(properties[:type]).to include(
        type: "string",
        enum: %w[credit debit]
      )
    end

    it "includes custom extensions" do
      schema = metadata.to_json_schema
      expect(schema[:"x-kumi-values"]).not_to be_empty
      expect(schema[:"x-kumi-traits"]).not_to be_empty
    end
  end

  describe "domain normalization" do
    let(:range_schema) do
      Class.new do
        extend Kumi::Schema

        schema do
          input do
            integer :exclusive_range, domain: 1...10
            integer :inclusive_range, domain: 1..10
            string :enum_field, domain: %w[a b c]
            integer :custom_field, domain: lambda(&:even?)
          end
        end
      end
    end

    it "handles exclusive ranges" do
      metadata = range_schema.schema_metadata
      domain = metadata.inputs[:exclusive_range][:domain]
      expect(domain).to include(
        type: :range,
        min: 1,
        max: 10,
        exclusive_end: true
      )
    end

    it "handles inclusive ranges" do
      metadata = range_schema.schema_metadata
      domain = metadata.inputs[:inclusive_range][:domain]
      expect(domain).to include(
        type: :range,
        min: 1,
        max: 10,
        exclusive_end: false
      )
    end

    it "handles custom proc domains" do
      metadata = range_schema.schema_metadata
      domain = metadata.inputs[:custom_field][:domain]
      expect(domain).to include(
        type: :custom,
        description: "custom validation function"
      )
    end
  end

  context "with complex schema" do
    let(:complex_schema) do
      Class.new do
        extend Kumi::Schema

        schema do
          input do
            hash :config, key: { type: :string }, val: { type: :any }
            array :items, elem: { type: :float }
          end

          trait :has_items, fn(:>, fn(:size, input.items), 0)

          value :total do
            on has_items, fn(:sum, input.items)
            base 0.0
          end
        end
      end
    end

    it "handles complex input types" do
      metadata = complex_schema.schema_metadata

      expect(metadata.inputs[:config]).to include(type: :hash)
      expect(metadata.inputs[:items]).to include(type: :array)
    end

    it "extracts function calls from expressions" do
      metadata = complex_schema.schema_metadata
      expect(metadata.functions).to have_key(:size)
      expect(metadata.functions).to have_key(:sum)
    end
  end
end
