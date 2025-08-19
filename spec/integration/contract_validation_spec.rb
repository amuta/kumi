# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Contract Validation Integration" do
  def build_schema(&block)
    Class.new do
      extend Kumi::Schema
      schema(&block)
    end
  end

  let(:schema) do
    build_schema do
      input do
        array :items do
          float :price
        end
      end

      # Classic repro: cascade with vector math inside
      trait :condition, input.items.price > 50.0
      value :result do
        on condition, input.items.price * 0.75
        base input.items.price
      end
    end
  end

  it "fails when ContractCheck runs before planning (missing join_plan)" do
    # Force ContractCheck to run early to assert the guard actually fires.
    early_passes = Kumi::Analyzer::DEFAULT_PASSES.filter_map do |p|
      # move ContractCheck just after FunctionSignature (before JoinReducePlanning)
      p == Kumi::Core::Analyzer::Passes::ContractCheckPass ? nil : p
    end

    early_passes.insert(
      early_passes.index(Kumi::Core::Analyzer::Passes::FunctionSignaturePass) + 1,
      Kumi::Core::Analyzer::Passes::ContractCheckPass
    )

    # Get the syntax tree from the schema to pass to analyzer
    syntax_tree = schema.instance_variable_get(:@__syntax_tree__)

    expect do
      Kumi::Analyzer.analyze!(syntax_tree, passes: early_passes)
    end.to raise_error(/Analyzer contract violation|Missing join_plan/) # developer error
  end

  it "passes when ContractCheck runs after join/reduce planning" do
    # Test both successful analysis and execution - the key is that it doesn't error
    result = schema.from(items: [{ price: 100.0 }, { price: 200.0 }])

    # The exact behavior isn't critical - we just want to verify the contract check passes
    # and the schema executes successfully with the full pipeline
    expect(result[:condition]).to eq([true, true]) # Both items > 50
    expect(result[:result]).to be_an(Array) # Result should be an array
    expect(result[:result].length).to eq(2) # Should have same length as input
  end
end