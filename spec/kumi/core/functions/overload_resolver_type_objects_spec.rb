# frozen_string_literal: true

require "spec_helper"
require "kumi/core/functions/overload_resolver"
require "kumi/core/types/value_objects"

RSpec.describe Kumi::Core::Functions::OverloadResolver do
  describe "type resolution with Type objects" do
    let(:string_type) { Kumi::Core::Types.scalar(:string) }
    let(:integer_type) { Kumi::Core::Types.scalar(:integer) }
    let(:float_type) { Kumi::Core::Types.scalar(:float) }
    let(:array_int_type) { Kumi::Core::Types.array(integer_type) }

    describe "#type_compatible? with Type objects" do
      let(:resolver) { described_class.new({}) }

      it "recognizes compatible scalar types" do
        expect(resolver.send(:type_compatible?, "string", string_type)).to be true
      end

      it "recognizes compatible array types with Type objects" do
        expect(resolver.send(:type_compatible?, "array", array_int_type)).to be true
      end

      it "recognizes incompatible types" do
        expect(resolver.send(:type_compatible?, "string", integer_type)).to be false
      end

      it "recognizes integer compatibility" do
        expect(resolver.send(:type_compatible?, "integer", integer_type)).to be true
      end

      it "recognizes float compatibility" do
        expect(resolver.send(:type_compatible?, "float", float_type)).to be true
      end

      it "recognizes hash compatibility" do
        hash_type = Kumi::Core::Types.scalar(:hash)
        expect(resolver.send(:type_compatible?, "hash", hash_type)).to be true
      end
    end

    describe "#match_score with Type objects" do
      let(:functions) do
        {
          "core.add:int" => Struct.new(:id, :params, :aliases, :param_names).new(
            "core.add:int",
            [{ "dtype" => "integer" }, { "dtype" => "integer" }],
            ["core.add"],
            %w[a b]
          ),
          "core.add:float" => Struct.new(:id, :params, :aliases, :param_names).new(
            "core.add:float",
            [{ "dtype" => "float" }, { "dtype" => "float" }],
            ["core.add"],
            %w[a b]
          )
        }
      end
      let(:resolver) { described_class.new(functions) }

      it "scores exact type matches higher" do
        int_params = functions["core.add:int"].params
        float_params = functions["core.add:float"].params

        int_score = resolver.send(:match_score, int_params, [integer_type, integer_type])
        float_score = resolver.send(:match_score, float_params, [integer_type, integer_type])

        expect(int_score).to be > float_score
      end

      it "scores zero for incompatible types" do
        int_params = functions["core.add:int"].params

        score = resolver.send(:match_score, int_params, [string_type, string_type])
        expect(score).to eq(0)
      end
    end

    describe "resolution with Type object arguments" do
      let(:functions) do
        {
          "core.max:int" => Struct.new(:id, :params, :aliases, :param_names).new(
            "core.max:int",
            [{ "dtype" => "integer" }],
            ["core.max", "max"],
            ["values"]
          ),
          "core.max:float" => Struct.new(:id, :params, :aliases, :param_names).new(
            "core.max:float",
            [{ "dtype" => "float" }],
            ["core.max", "max"],
            ["values"]
          )
        }
      end
      let(:resolver) { described_class.new(functions) }

      it "resolves to correct overload for integer types" do
        result = resolver.resolve("max", [integer_type])
        expect(result).to eq("core.max:int")
      end

      it "resolves to correct overload for float types" do
        result = resolver.resolve("max", [float_type])
        expect(result).to eq("core.max:float")
      end

      it "prefers exact matches over generic matches" do
        result = resolver.resolve("max", [integer_type])
        expect(result).to eq("core.max:int")
      end
    end
  end
end
