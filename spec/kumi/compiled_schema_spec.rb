# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kumi::Core::CompiledSchema do
  let(:trait_lambda) { ->(data) { data[:age] >= 18 } }
  let(:attr_lambda) { ->(data) { data[:name].upcase } }
  let(:bindings) do
    {
      is_adult: [:trait, trait_lambda],
      display_name: [:attr, attr_lambda]
    }
  end
  let(:compiled_schema) { described_class.new(bindings) }
  let(:valid_data) { { age: 25, name: "Alice" } }

  describe "#initialize" do
    it "stores bindings" do
      expect(compiled_schema.instance_variable_get(:@bindings)).to eq(bindings)
    end
  end

  describe "#evaluate" do
    context "when no keys are specified" do
      it "evaluates all traits and attributes" do
        result = compiled_schema.evaluate(valid_data)

        expect(result).to eq({
                               is_adult: true,
                               display_name: "ALICE"
                             })
      end

      it "merges traits and attributes" do
        result = compiled_schema.evaluate(valid_data)

        expect(result.keys).to contain_exactly(:is_adult, :display_name)
      end
    end

    context "when specific keys are provided" do
      it "evaluates only the requested keys" do
        result = compiled_schema.evaluate(valid_data, :is_adult)

        expect(result).to eq({ is_adult: true })
      end

      it "evaluates multiple requested keys" do
        result = compiled_schema.evaluate(valid_data, :is_adult, :display_name)

        expect(result).to eq({
                               is_adult: true,
                               display_name: "ALICE"
                             })
      end

      it "raises error for unknown keys" do
        expect do
          compiled_schema.evaluate(valid_data, :unknown_key)
        end.to raise_error(Kumi::Errors::RuntimeError, /No binding named unknown_key/)
      end
    end
  end

  describe "#evaluate_binding" do
    it "evaluates a specific binding by name" do
      result = compiled_schema.evaluate_binding(:is_adult, valid_data)

      expect(result).to be true
    end

    it "evaluates attribute bindings" do
      result = compiled_schema.evaluate_binding(:display_name, valid_data)

      expect(result).to eq("ALICE")
    end
  end

  describe "error handling" do
    it "handles lambda execution errors" do
      error_lambda = ->(_data) { raise StandardError, "Lambda error" }
      error_bindings = { error_binding: [:attr, error_lambda] }
      error_schema = described_class.new(error_bindings)

      expect do
        error_schema.evaluate_binding(:error_binding, valid_data)
      end.to raise_error(StandardError, "Lambda error")
    end
  end

  describe "edge cases" do
    it "handles empty bindings" do
      empty_schema = described_class.new({})
      result = empty_schema.evaluate(valid_data)

      expect(result).to eq({})
    end

    it "handles bindings with nil values" do
      nil_lambda = ->(_data) {}
      nil_bindings = { nil_value: [:attr, nil_lambda] }
      nil_schema = described_class.new(nil_bindings)

      result = nil_schema.evaluate(valid_data)

      expect(result).to eq({ nil_value: nil })
    end

    it "handles complex data structures" do
      complex_data = {
        user: { name: "Complex", age: 30 },
        metadata: { created_at: Time.now }
      }
      complex_lambda = ->(data) { data[:user][:name] }
      complex_bindings = { user_name: [:attr, complex_lambda] }
      complex_schema = described_class.new(complex_bindings)

      result = complex_schema.evaluate(complex_data)

      expect(result).to eq({ user_name: "Complex" })
    end
  end
end
