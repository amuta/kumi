# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kumi::Runner do
  let(:context) { { age: 25, name: "Alice", income: 50_000 } }
  let(:attr_lambda) { ->(data) { data[:name].upcase } }
  let(:trait_lambda) { ->(data) { data[:age] >= 18 } }
  let(:bindings) do
    {
      display_name: [:attr, attr_lambda],
      is_adult: [:trait, trait_lambda]
    }
  end
  let(:schema) { Kumi::CompiledSchema.new(bindings) }
  let(:node_index) { {} } # Simple empty node index for basic tests
  let(:runner) { described_class.new(context, schema, node_index) }

  describe "#initialize" do
    it "stores context, schema, and node_index" do
      expect(runner.context).to eq(context)
      expect(runner.schema).to eq(schema)
      expect(runner.node_index).to eq(node_index)
    end
  end

  describe "#slice" do
    it "evaluates multiple keys using schema" do
      result = runner.slice(:display_name, :is_adult)

      expect(result).to eq({
                             display_name: "ALICE",
                             is_adult: true
                           })
    end

    it "evaluates single key" do
      result = runner.slice(:display_name)

      expect(result).to eq({ display_name: "ALICE" })
    end

    it "evaluates all keys when none specified" do
      result = runner.slice

      expect(result).to eq({
                             display_name: "ALICE",
                             is_adult: true
                           })
    end

    it "delegates to schema.evaluate" do
      expect(schema).to receive(:evaluate).with(context, :display_name).and_return({ display_name: "ALICE" })

      runner.slice(:display_name)
    end
  end

  describe "#input" do
    it "returns the context" do
      expect(runner.input).to eq(context)
    end

    it "provides access to original input data" do
      expect(runner.input[:name]).to eq("Alice")
      expect(runner.input[:age]).to eq(25)
    end
  end

  describe "#fetch" do
    it "evaluates and caches a single binding" do
      result = runner.fetch(:display_name)

      expect(result).to eq("ALICE")
    end

    it "caches results for subsequent calls" do
      expect(schema).to receive(:evaluate_binding).once.with(:display_name, context).and_return("ALICE")

      # First call should evaluate
      result1 = runner.fetch(:display_name)
      # Second call should use cache
      result2 = runner.fetch(:display_name)

      expect(result1).to eq("ALICE")
      expect(result2).to eq("ALICE")
    end

    it "evaluates different keys independently" do
      result1 = runner.fetch(:display_name)
      result2 = runner.fetch(:is_adult)

      expect(result1).to eq("ALICE")
      expect(result2).to be true
    end

    it "handles nil values in cache" do
      allow(schema).to receive(:evaluate_binding).with(:nil_value, context).and_return(nil)

      result1 = runner.fetch(:nil_value)
      result2 = runner.fetch(:nil_value)

      expect(result1).to be_nil
      expect(result2).to be_nil
    end

    it "initializes cache if not present" do
      expect(runner.instance_variable_get(:@cache)).to be_nil

      runner.fetch(:display_name)

      expect(runner.instance_variable_get(:@cache)).to be_a(Hash)
    end
  end

  describe "#explain" do
    it "clears cache for fresh explanation" do
      # Pre-populate cache
      runner.fetch(:display_name)
      expect(runner.instance_variable_get(:@cache)).not_to be_empty

      # Mock the explain_recursive to avoid actual explanation logic
      allow(runner).to receive(:explain_recursive).and_return("mocked explanation")

      runner.explain(:display_name)

      # Cache should be cleared after explain
      expect(runner.instance_variable_get(:@cache)).to eq({})
    end

    it "calls explain_recursive with the key" do
      expect(runner).to receive(:explain_recursive).with(:display_name).and_return("explanation")

      result = runner.explain(:display_name)

      expect(result).to eq("explanation")
    end

    context "with basic explanation" do
      it "returns a string explanation" do
        allow(runner).to receive(:explain_recursive).and_return("mock explanation")

        result = runner.explain(:display_name)

        expect(result).to be_a(String)
        expect(result).to eq("mock explanation")
      end
    end
  end

  describe "edge cases" do
    it "handles empty context" do
      # Use a schema with no bindings for empty context test
      empty_schema = Kumi::CompiledSchema.new({})
      empty_runner = described_class.new({}, empty_schema, {})

      expect { empty_runner.slice }.not_to raise_error
    end

    it "handles missing keys gracefully" do
      expect do
        runner.fetch(:nonexistent)
      end.to raise_error(Kumi::Errors::RuntimeError, /No binding named nonexistent/)
    end

    it "preserves cache across multiple fetch calls" do
      runner.fetch(:display_name)
      runner.fetch(:is_adult)

      cache = runner.instance_variable_get(:@cache)
      expect(cache.keys).to contain_exactly(:display_name, :is_adult)
    end

    it "handles complex data structures" do
      complex_context = {
        user: { name: "Complex", age: 30 },
        scores: [85, 90, 78]
      }
      complex_lambda = ->(data) { data[:user][:name] }
      complex_bindings = { user_name: [:attr, complex_lambda] }
      complex_schema = Kumi::CompiledSchema.new(complex_bindings)
      complex_runner = described_class.new(complex_context, complex_schema, {})

      result = complex_runner.fetch(:user_name)

      expect(result).to eq("Complex")
    end
  end

  describe "integration with CompiledSchema" do
    it "works end-to-end for trait evaluation" do
      adult_context = { age: 25, name: "Adult" }
      minor_context = { age: 16, name: "Minor" }

      adult_result = described_class.new(adult_context, schema, {}).fetch(:is_adult)
      minor_result = described_class.new(minor_context, schema, {}).fetch(:is_adult)

      expect(adult_result).to be true
      expect(minor_result).to be false
    end

    it "works end-to-end for attribute evaluation" do
      test_context = { age: 30, name: "test_user" }

      result = described_class.new(test_context, schema, {}).fetch(:display_name)

      expect(result).to eq("TEST_USER")
    end
  end
end
