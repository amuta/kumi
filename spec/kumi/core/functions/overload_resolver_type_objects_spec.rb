# frozen_string_literal: true

require "spec_helper"
require "kumi/core/functions/overload_resolver"
require "kumi/core/types/value_objects"

RSpec.describe Kumi::Core::Functions::OverloadResolver do
  let(:string_type)  { Kumi::Core::Types.scalar(:string) }
  let(:integer_type) { Kumi::Core::Types.scalar(:integer) }
  let(:float_type)   { Kumi::Core::Types.scalar(:float) }

  def fn(id, params, aliases)
    Struct.new(:id, :params, :aliases, :param_names).new(id, params, aliases, params.map { |p| p["name"]&.to_sym })
  end

  describe "#resolve" do
    let(:functions) do
      {
        "core.max:int" => fn("core.max:int", [{ "name" => "values", "dtype" => "integer" }], %w[core.max max]),
        "core.max:float" => fn("core.max:float", [{ "name" => "values", "dtype" => "float" }], %w[core.max max])
      }
    end
    let(:resolver) { described_class.new(functions) }

    it "resolves to the integer overload for integer arguments" do
      expect(resolver.resolve("max", [integer_type])).to eq("core.max:int")
    end

    it "resolves to the float overload for float arguments" do
      expect(resolver.resolve("max", [float_type])).to eq("core.max:float")
    end

    it "raises a precise, argument-level error when no overload matches" do
      expect { resolver.resolve("max", [string_type]) }
        .to raise_error(described_class::ResolutionError,
                        /argument 1 \(values\) expected (integer|float), got string/)
    end

    it "reports arity mismatches" do
      expect { resolver.resolve("max", [integer_type, integer_type]) }
        .to raise_error(described_class::ResolutionError, /expects 1 argument\(s\), got 2/)
    end

    it "raises for an unknown function" do
      expect { resolver.resolve("nope", [integer_type]) }
        .to raise_error(described_class::ResolutionError, /unknown function nope/)
    end
  end

  describe "single-overload constraint checking" do
    let(:functions) do
      { "core.upcase" => fn("core.upcase", [{ "name" => "s", "dtype" => "string" }], %w[upcase]) }
    end
    let(:resolver) { described_class.new(functions) }

    it "accepts a matching argument" do
      expect(resolver.resolve("upcase", [string_type])).to eq("core.upcase")
    end

    it "names the offending argument and the expected constraint on mismatch" do
      expect { resolver.resolve("upcase", [integer_type]) }
        .to raise_error(described_class::ResolutionError, /argument 1 \(s\) expected string, got integer/)
    end
  end
end
