# frozen_string_literal: true
require "spec_helper"

RSpec.describe "Normalize → Resolve" do
  let(:schema) { Kumi::Syntax::Root.new }

  def run_normalize_pass(node_index)
    state = Kumi::Core::Analyzer::AnalysisState.new({ node_index: node_index })
    registry = Kumi::Core::Functions::RegistryV2.load_from_file
    state = state.with(:registry, registry)
    Kumi::Core::Analyzer::Passes::CallNameNormalizePass.new(schema, state).run([])
  end

  it "annotates include? as contains" do
    call = Kumi::Syntax::CallExpression.new(:'include?', [
      Kumi::Syntax::ArrayExpression.new([Kumi::Syntax::Literal.new(1)]),
      Kumi::Syntax::Literal.new(1)
    ])
    node_index = { call.object_id => { type: 'CallExpression', node: call, metadata: {} } }

    run_normalize_pass(node_index)

    expect(node_index[call.object_id][:metadata][:canonical_name]).to eq(:contains)
  end

  it "normalizes arithmetic operations from Sugar" do
    multiply_call = Kumi::Syntax::CallExpression.new(:multiply, [
      Kumi::Syntax::Literal.new(2),
      Kumi::Syntax::Literal.new(3)
    ])
    subtract_call = Kumi::Syntax::CallExpression.new(:subtract, [
      Kumi::Syntax::Literal.new(5),
      Kumi::Syntax::Literal.new(1)
    ])
    
    node_index = {
      multiply_call.object_id => { type: 'CallExpression', node: multiply_call, metadata: {} },
      subtract_call.object_id => { type: 'CallExpression', node: subtract_call, metadata: {} }
    }

    run_normalize_pass(node_index)

    expect(node_index[multiply_call.object_id][:metadata][:canonical_name]).to eq(:mul)
    expect(node_index[subtract_call.object_id][:metadata][:canonical_name]).to eq(:sub)
  end

  it "normalizes comparison operations" do
    eq_call = Kumi::Syntax::CallExpression.new(:'==', [
      Kumi::Syntax::Literal.new(1),
      Kumi::Syntax::Literal.new(1)
    ])
    gte_call = Kumi::Syntax::CallExpression.new(:gte, [
      Kumi::Syntax::Literal.new(5),
      Kumi::Syntax::Literal.new(3)
    ])
    
    node_index = {
      eq_call.object_id => { type: 'CallExpression', node: eq_call, metadata: {} },
      gte_call.object_id => { type: 'CallExpression', node: gte_call, metadata: {} }
    }

    run_normalize_pass(node_index)

    expect(node_index[eq_call.object_id][:metadata][:canonical_name]).to eq(:eq)
    expect(node_index[gte_call.object_id][:metadata][:canonical_name]).to eq(:ge)
  end

  it "annotates canonical names for downstream passes" do
    call = Kumi::Syntax::CallExpression.new(:at, [
      Kumi::Syntax::ArrayExpression.new([Kumi::Syntax::Literal.new(1), Kumi::Syntax::Literal.new(2)]),
      Kumi::Syntax::Literal.new(0)
    ])
    node_index = { call.object_id => { type: 'CallExpression', node: call, metadata: {} } }

    run_normalize_pass(node_index)

    expect(node_index[call.object_id][:metadata][:canonical_name]).to eq(:get)
  end
end