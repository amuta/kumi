# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kumi::Core::Types::Inference do
  describe ".infer_from_value" do
    let(:string_type) { Kumi::Core::Types.scalar(:string) }
    let(:integer_type) { Kumi::Core::Types.scalar(:integer) }
    let(:float_type) { Kumi::Core::Types.scalar(:float) }
    let(:boolean_type) { Kumi::Core::Types.scalar(:boolean) }
    let(:symbol_type) { Kumi::Core::Types.scalar(:symbol) }
    let(:regexp_type) { Kumi::Core::Types.scalar(:regexp) }
    let(:time_type) { Kumi::Core::Types.scalar(:time) }
    let(:date_type) { Kumi::Core::Types.scalar(:date) }
    let(:datetime_type) { Kumi::Core::Types.scalar(:datetime) }
    let(:any_type) { Kumi::Core::Types.scalar(:any) }
    let(:hash_type) { Kumi::Core::Types.scalar(:hash) }

    context "with primitive values" do
      it "infers string type from string values" do
        expect(described_class.infer_from_value("hello")).to eq(string_type)
        expect(described_class.infer_from_value("")).to eq(string_type)
      end

      it "infers integer type from integer values" do
        expect(described_class.infer_from_value(42)).to eq(integer_type)
        expect(described_class.infer_from_value(0)).to eq(integer_type)
        expect(described_class.infer_from_value(-10)).to eq(integer_type)
      end

      it "infers float type from float values" do
        expect(described_class.infer_from_value(3.14)).to eq(float_type)
        expect(described_class.infer_from_value(0.0)).to eq(float_type)
        expect(described_class.infer_from_value(-2.5)).to eq(float_type)
      end

      it "infers boolean type from boolean values" do
        expect(described_class.infer_from_value(true)).to eq(boolean_type)
        expect(described_class.infer_from_value(false)).to eq(boolean_type)
      end

      it "infers symbol type from symbol values" do
        expect(described_class.infer_from_value(:hello)).to eq(symbol_type)
        expect(described_class.infer_from_value(:test)).to eq(symbol_type)
      end

      it "infers regexp type from regexp values" do
        expect(described_class.infer_from_value(/pattern/)).to eq(regexp_type)
        expect(described_class.infer_from_value(/\d+/)).to eq(regexp_type)
      end

      it "infers time type from time values" do
        expect(described_class.infer_from_value(Time.now)).to eq(time_type)
      end

      it "infers date type from date values" do
        expect(described_class.infer_from_value(Date.today)).to eq(date_type)
      end

      it "infers datetime type from datetime values" do
        expect(described_class.infer_from_value(DateTime.now)).to eq(datetime_type)
      end
    end

    context "with array values" do
      it "infers generic array type from empty arrays" do
        result = described_class.infer_from_value([])
        expected = Kumi::Core::Types.array(any_type)
        expect(result).to eq(expected)
      end

      it "infers array type from first element" do
        result = described_class.infer_from_value(%w[hello world])
        expected = Kumi::Core::Types.array(string_type)
        expect(result).to eq(expected)
      end

      it "infers array type with mixed elements based on first" do
        result = described_class.infer_from_value([42, "hello", true])
        expected = Kumi::Core::Types.array(integer_type)
        expect(result).to eq(expected)
      end

      it "infers nested array types" do
        result = described_class.infer_from_value([[1, 2], [3, 4]])
        inner_array = Kumi::Core::Types.array(integer_type)
        expected = Kumi::Core::Types.array(inner_array)
        expect(result).to eq(expected)
      end

      it "infers array with hash elements" do
        result = described_class.infer_from_value([{ name: "Alice" }, { name: "Bob" }])
        expected = Kumi::Core::Types.array(hash_type)
        expect(result).to eq(expected)
      end
    end

    context "with hash values" do
      it "infers scalar hash type from empty hashes" do
        result = described_class.infer_from_value({})
        expect(result).to eq(hash_type)
      end

      it "infers scalar hash type from hash with any content" do
        result = described_class.infer_from_value({ name: "Alice", age: 30 })
        expect(result).to eq(hash_type)
      end

      it "infers scalar hash type with string keys" do
        result = described_class.infer_from_value({ "name" => "Alice", "age" => 30 })
        expect(result).to eq(hash_type)
      end

      it "infers scalar hash type from nested hashes" do
        result = described_class.infer_from_value({ user: { name: "Alice", details: { age: 30 } } })
        expect(result).to eq(hash_type)
      end

      it "infers scalar hash type with array values" do
        result = described_class.infer_from_value({ scores: [85, 90, 78] })
        expect(result).to eq(hash_type)
      end
    end

    context "with unknown values" do
      it "falls back to :any for unknown types" do
        custom_object = Object.new
        expect(described_class.infer_from_value(custom_object)).to eq(any_type)
      end

      it "falls back to :any for nil values" do
        expect(described_class.infer_from_value(nil)).to eq(any_type)
      end
    end
  end
end
