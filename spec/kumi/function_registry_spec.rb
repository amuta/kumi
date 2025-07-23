# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kumi::FunctionRegistry do
  describe "registry management" do
    it "lists all available functions" do
      functions = described_class.all_functions
      expect(functions).to be_an(Array)
      expect(functions).not_to be_empty
      expect(functions.size).to be > 30 # We should have plenty of functions
    end

    it "provides category accessors" do
      expect(described_class.comparison_operators).to include(:==, :>, :<, :>=, :<=, :!=, :between?)
      expect(described_class.math_operations).to include(:add, :subtract, :multiply, :divide)
      expect(described_class.string_operations).to include(:upcase, :downcase, :strip)
      expect(described_class.logical_operations).to include(:and, :or, :not)
      expect(described_class.collection_operations).to include(:sum, :min, :max, :size)
      expect(described_class.conditional_operations).to include(:conditional, :if, :coalesce)
      expect(described_class.type_operations).to include(:fetch, :has_key?, :keys, :values, :at)
    end

    it "ensures all category functions are in the main registry" do
      all_category_functions = [
        described_class.comparison_operators,
        described_class.math_operations,
        described_class.string_operations,
        described_class.logical_operations,
        described_class.collection_operations,
        described_class.conditional_operations,
        described_class.type_operations
      ].flatten

      all_category_functions.each do |function_name|
        expect(described_class.supported?(function_name)).to be true
      end
    end

    it "has alias method for compatibility" do
      expect(described_class.all).to eq(described_class.all_functions)
    end
  end

  describe "function lookup and validation" do
    let(:test_function) { :add } # Known to exist

    it "checks if functions are supported" do
      expect(described_class.supported?(test_function)).to be true
      expect(described_class.supported?(:nonexistent_function)).to be false
    end

    it "identifies core operators correctly" do
      expect(described_class.operator?(:==)).to be true
      expect(described_class.operator?(:>)).to be true
      expect(described_class.operator?(:add)).to be false
      expect(described_class.operator?("not_a_symbol")).to be false
      expect(described_class.operator?(nil)).to be false
    end

    it "fetches function lambdas" do
      fn = described_class.fetch(test_function)
      expect(fn).to respond_to(:call)
      expect(fn.call(2, 3)).to eq(5)
    end

    it "provides function signatures" do
      signature = described_class.signature(test_function)
      expect(signature).to have_key(:arity)
      expect(signature).to have_key(:param_types)
      expect(signature).to have_key(:return_type)
      expect(signature).to have_key(:description)
      expect(signature[:description]).to be_a(String)
    end
  end

  describe "error handling" do
    it "raises UnknownFunction for unsupported functions" do
      expect do
        described_class.fetch(:unknown_function)
      end.to raise_error(Kumi::FunctionRegistry::UnknownFunction, "Unknown function: unknown_function")
    end

    it "raises UnknownFunction for signature of unsupported functions" do
      expect do
        described_class.signature(:unknown_function)
      end.to raise_error(Kumi::FunctionRegistry::UnknownFunction, "Unknown function: unknown_function")
    end

    it "handles nil function names gracefully" do
      expect(described_class.supported?(nil)).to be false
      expect(described_class.operator?(nil)).to be false
    end
  end

  describe "custom function registration" do
    after { described_class.reset! }

    it "can register simple custom functions" do
      described_class.register(:custom_double) { |x| x * 2 }

      expect(described_class.supported?(:custom_double)).to be true
      fn = described_class.fetch(:custom_double)
      expect(fn.call(5)).to eq(10)
    end

    it "can register functions with metadata" do
      described_class.register_with_metadata(
        :custom_triple,
        ->(value) { value * 3 },
        arity: 1,
        param_types: [:integer],
        return_type: :integer,
        description: "Triple the input value"
      )

      expect(described_class.supported?(:custom_triple)).to be true
      signature = described_class.signature(:custom_triple)
      expect(signature[:arity]).to eq(1)
      expect(signature[:param_types]).to eq([:integer])
      expect(signature[:return_type]).to eq(:integer)
      expect(signature[:description]).to eq("Triple the input value")

      fn = described_class.fetch(:custom_triple)
      expect(fn.call(4)).to eq(12)
    end

    it "prevents duplicate registration" do
      described_class.register(:custom_func) { |x| x }

      expect do
        described_class.register(:custom_func) { |x| x * 2 }
      end.to raise_error(ArgumentError, "Function :custom_func already registered")
    end

    it "can auto-register from classes" do
      test_class = Class.new do
        def test_method(value)
          value.upcase
        end
      end

      described_class.auto_register(test_class)

      expect(described_class.supported?(:test_method)).to be true
      fn = described_class.fetch(:test_method)
      expect(fn.call("hello")).to eq("HELLO")
    end

    it "skips already supported functions during auto-registration" do
      # Create a class with a method that conflicts with existing function
      test_class = Class.new do
        def add(value)
          "custom_add: #{value}"
        end

        def new_method(value)
          "new: #{value}"
        end
      end

      original_add = described_class.fetch(:add)
      described_class.auto_register(test_class)

      # Existing function should be unchanged
      expect(described_class.fetch(:add)).to be(original_add)

      # New function should be registered
      expect(described_class.supported?(:new_method)).to be true
      expect(described_class.fetch(:new_method).call("test")).to eq("new: test")
    end
  end

  describe "development helpers" do
    it "can reset the registry" do
      original_functions = described_class.all_functions.dup
      described_class.register(:temp_func) { |x| x }

      expect(described_class.supported?(:temp_func)).to be true

      described_class.reset!

      expect(described_class.supported?(:temp_func)).to be false
      expect(described_class.all_functions).to eq(original_functions)
    end

    it "maintains function count consistency after reset" do
      original_count = described_class.all_functions.size

      described_class.register(:temp1) { |x| x }
      described_class.register(:temp2) { |x| x }
      expect(described_class.all_functions.size).to eq(original_count + 2)

      described_class.reset!
      expect(described_class.all_functions.size).to eq(original_count)
    end
  end

  describe "function categories completeness" do
    it "verifies all registered functions belong to a category" do
      all_functions = described_class.all_functions
      categorized_functions = [
        described_class.comparison_operators,
        described_class.math_operations,
        described_class.string_operations,
        described_class.logical_operations,
        described_class.collection_operations,
        described_class.conditional_operations,
        described_class.type_operations
      ].flatten.uniq

      # Every function should be in at least one category
      uncategorized = all_functions - categorized_functions
      expect(uncategorized).to be_empty, "Found uncategorized functions: #{uncategorized}"
    end

    it "has no duplicate functions across registry" do
      all_functions = described_class.all_functions
      expect(all_functions.uniq.size).to eq(all_functions.size)
    end
  end

  describe "Entry struct compatibility" do
    it "exposes Entry struct for compatibility" do
      expect(described_class::Entry).to eq(Kumi::FunctionRegistry::FunctionBuilder::Entry)
    end

    it "can create Entry instances" do
      entry = described_class::Entry.new(
        fn: ->(x) { x * 2 },
        arity: 1,
        param_types: [:integer],
        return_type: :integer,
        description: "Double the value"
      )

      expect(entry.fn.call(5)).to eq(10)
      expect(entry.arity).to eq(1)
      expect(entry.param_types).to eq([:integer])
      expect(entry.return_type).to eq(:integer)
      expect(entry.description).to eq("Double the value")
    end
  end

  describe "core operators constant" do
    it "defines core operators correctly" do
      expect(described_class::CORE_OPERATORS).to eq(%i[== > < >= <= != between?])
      expect(described_class::CORE_OPERATORS).to be_frozen
    end

    it "ensures all core operators are supported" do
      described_class::CORE_OPERATORS.each do |op|
        expect(described_class.supported?(op)).to be true
        expect(described_class.operator?(op)).to be true
      end
    end
  end
end
