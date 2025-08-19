# frozen_string_literal: true
require "spec_helper"

RSpec.describe Kumi::Core::Analyzer::Passes::CallNameNormalizePass do
  let(:errors) { [] }
  let(:schema) { Kumi::Syntax::Root.new }

  def run_pass(initial_state)
    state = Kumi::Core::Analyzer::AnalysisState.new(initial_state)
    registry = Kumi::Core::Functions::RegistryV2.load_from_file
    state = state.with(:registry, registry)
    described_class.new(schema, state).run(errors)
  end

  it "annotates function names with canonical equivalents" do
    call = Kumi::Syntax::CallExpression.new(:multiply, [Kumi::Syntax::Literal.new(2), Kumi::Syntax::Literal.new(3)])
    node_index = {
      call.object_id => { type: 'CallExpression', node: call, metadata: {} }
    }
    
    run_pass({ node_index: node_index })

    expect(node_index[call.object_id][:metadata][:canonical_name]).to eq(:mul)
  end

  it "annotates canonical names as-is" do
    call = Kumi::Syntax::CallExpression.new(:add, [Kumi::Syntax::Literal.new(1), Kumi::Syntax::Literal.new(2)])
    node_index = {
      call.object_id => { type: 'CallExpression', node: call, metadata: {} }
    }
    
    run_pass({ node_index: node_index })

    expect(node_index[call.object_id][:metadata][:canonical_name]).to eq(:add)
  end

  it "handles multiple CallExpression nodes" do
    call1 = Kumi::Syntax::CallExpression.new(:subtract, [Kumi::Syntax::Literal.new(5), Kumi::Syntax::Literal.new(3)])
    call2 = Kumi::Syntax::CallExpression.new(:divide, [Kumi::Syntax::Literal.new(10), Kumi::Syntax::Literal.new(2)])
    call3 = Kumi::Syntax::CallExpression.new(:add, [Kumi::Syntax::Literal.new(1), Kumi::Syntax::Literal.new(1)])
    
    node_index = {
      call1.object_id => { type: 'CallExpression', node: call1, metadata: {} },
      call2.object_id => { type: 'CallExpression', node: call2, metadata: {} },
      call3.object_id => { type: 'CallExpression', node: call3, metadata: {} }
    }
    
    run_pass({ node_index: node_index })

    expect(node_index[call1.object_id][:metadata][:canonical_name]).to eq(:sub)
    expect(node_index[call2.object_id][:metadata][:canonical_name]).to eq(:div)
    expect(node_index[call3.object_id][:metadata][:canonical_name]).to eq(:add)
  end

  it "ignores non-CallExpression nodes" do
    literal = Kumi::Syntax::Literal.new(42)
    node_index = {
      literal.object_id => { type: 'Literal', node: literal, metadata: {} }
    }
    
    expect { run_pass({ node_index: node_index }) }.not_to raise_error
  end

  it "requires node_index to be present" do
    expect { run_pass({}) }.to raise_error(/node_index/)
  end
end