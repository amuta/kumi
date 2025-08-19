# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Vector Function Signature Matching" do
  describe "basic vector operations" do
    it "handles array literals correctly" do
      schema = build_schema do
        input { float :income }
        value :test_array, [1.0, 2.0, 3.0]
        value :result, test_array
      end

      result = schema.from(income: 100.0)
      expect(result[:result]).to eq([1.0, 2.0, 3.0])
    end

    it "handles array.get with scalar arguments" do
      schema = build_schema do
        input { float :income }
        value :rates, [0.1, 0.2, 0.3]
        value :index, 1
        value :result, fn(:get, rates, index)
      end

      result = schema.from(income: 100.0)
      expect(result[:result]).to eq(0.2)
    end
  end

  describe "array literal aggregation" do
    it "handles max with array literal correctly" do
      schema = build_schema do
        input { float :income }
        value :test_values, [100.0, 200.0, 150.0]
        value :result, fn(:max, test_values)
      end

      result = schema.from(income: 100.0)
      expect(result[:result]).to eq(200.0)
    end
  end

  describe "type mismatch error messages" do
    it "provides helpful error for searchsorted with array literal instead of input array" do
      expect do
        build_schema do
          input { float :income }
          value :edges, [0.0, 50.0, 100.0]
          value :result, fn(:searchsorted, edges, input.income)
        end
      end.to raise_error(Kumi::Core::Errors::TypeError) do |error|
        expect(error.message).to include("argument 1 of `fn(:searchsorted)`")
        expect(error.message).to include("got reference to declaration `edges` of inferred type {:array=>:float}")
        expect(error.message).to include("expects float")
      end
    end
  end

  describe "working vector patterns" do
    it "demonstrates pattern that works with aggregates" do
      schema = build_schema do
        input do
          array :items do
            float :price
          end
        end

        value :total, fn(:sum, input.items.price)
      end

      result = schema.from(items: [{ price: 100.0 }, { price: 200.0 }])
      expect(result[:total]).to eq(300.0)
    end
  end

  describe "signature resolution internals" do
    it "correctly identifies function signatures from registry" do
      # Test that the function registry has the expected signatures
      registry = Kumi::Core::Functions::RegistryV2.load_from_file

      max_func = registry.resolve("agg.max")
      expect(max_func.signatures.map(&:to_signature_string)).to include("(i)->()")

      searchsorted_func = registry.resolve("struct.searchsorted")
      expect(searchsorted_func.signatures.map(&:to_signature_string)).to include("(i),()->()")

      get_func = registry.resolve("array.get")
      expect(get_func.signatures.map(&:to_signature_string)).to include("(),()->()")
    end
  end
end
