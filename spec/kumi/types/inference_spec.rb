# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kumi::Core::Types::Inference do
  describe ".infer_from_value" do
    context "with primitive values" do
      it "infers string type from string values" do
        expect(described_class.infer_from_value("hello")).to eq(:string)
        expect(described_class.infer_from_value("")).to eq(:string)
      end

      it "infers integer type from integer values" do
        expect(described_class.infer_from_value(42)).to eq(:integer)
        expect(described_class.infer_from_value(0)).to eq(:integer)
        expect(described_class.infer_from_value(-10)).to eq(:integer)
      end

      it "infers float type from float values" do
        expect(described_class.infer_from_value(3.14)).to eq(:float)
        expect(described_class.infer_from_value(0.0)).to eq(:float)
        expect(described_class.infer_from_value(-2.5)).to eq(:float)
      end

      it "infers boolean type from boolean values" do
        expect(described_class.infer_from_value(true)).to eq(:boolean)
        expect(described_class.infer_from_value(false)).to eq(:boolean)
      end

      it "infers symbol type from symbol values" do
        expect(described_class.infer_from_value(:hello)).to eq(:symbol)
        expect(described_class.infer_from_value(:test)).to eq(:symbol)
      end

      it "infers regexp type from regexp values" do
        expect(described_class.infer_from_value(/pattern/)).to eq(:regexp)
        expect(described_class.infer_from_value(/\d+/)).to eq(:regexp)
      end

      it "infers time type from time values" do
        expect(described_class.infer_from_value(Time.now)).to eq(:time)
      end

      it "infers date type from date values" do
        expect(described_class.infer_from_value(Date.today)).to eq(:date)
      end

      it "infers datetime type from datetime values" do
        expect(described_class.infer_from_value(DateTime.now)).to eq(:datetime)
      end
    end

    context "with array values" do
      it "infers generic array type from empty arrays" do
        result = described_class.infer_from_value([])
        expect(result).to eq({ array: :any })
      end

      it "infers array type from first element" do
        result = described_class.infer_from_value(%w[hello world])
        expect(result).to eq({ array: :string })
      end

      it "infers array type with mixed elements based on first" do
        result = described_class.infer_from_value([42, "hello", true])
        expect(result).to eq({ array: :integer })
      end

      it "infers nested array types" do
        result = described_class.infer_from_value([[1, 2], [3, 4]])
        expect(result).to eq({ array: { array: :integer } })
      end

      it "infers array with hash elements" do
        result = described_class.infer_from_value([{ name: "Alice" }, { name: "Bob" }])
        expect(result).to eq({ array: { hash: %i[symbol string] } })
      end
    end

    context "with hash values" do
      it "infers generic hash type from empty hashes" do
        result = described_class.infer_from_value({})
        expect(result).to eq({ hash: %i[any any] })
      end

      it "infers hash type from first key-value pair" do
        result = described_class.infer_from_value({ name: "Alice", age: 30 })
        expect(result).to eq({ hash: %i[symbol string] })
      end

      it "infers hash type with string keys" do
        result = described_class.infer_from_value({ "name" => "Alice", "age" => 30 })
        expect(result).to eq({ hash: %i[string string] })
      end

      it "infers nested hash types" do
        result = described_class.infer_from_value({ user: { name: "Alice", details: { age: 30 } } })
        expect(result).to eq({ hash: [:symbol, { hash: %i[symbol string] }] })
      end

      it "infers hash with array values" do
        result = described_class.infer_from_value({ scores: [85, 90, 78] })
        expect(result).to eq({ hash: [:symbol, { array: :integer }] })
      end
    end

    context "with unknown values" do
      it "falls back to :any for unknown types" do
        custom_object = Object.new
        expect(described_class.infer_from_value(custom_object)).to eq(:any)
      end

      it "falls back to :any for nil values" do
        expect(described_class.infer_from_value(nil)).to eq(:any)
      end
    end

    context "with complex nested structures" do
      it "handles deeply nested structures" do
        complex_data = {
          users: [
            { name: "Alice", scores: [85, 90] },
            { name: "Bob", scores: [78, 82] }
          ],
          metadata: {
            created_at: Time.now,
            version: 1.0
          }
        }

        result = described_class.infer_from_value(complex_data)
        expect(result).to eq({
                               hash: [
                                 :symbol,
                                 {
                                   array: {
                                     hash: %i[symbol string]
                                   }
                                 }
                               ]
                             })
      end
    end
  end
end
