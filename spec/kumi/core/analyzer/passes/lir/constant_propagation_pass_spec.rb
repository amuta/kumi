# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kumi::Core::Analyzer::Passes::LIR::ConstantPropagationPass do
  let(:build) { Kumi::Core::LIR::Build }
  let(:schema) { instance_double("Schema") }
  let(:ids) { Kumi::Core::LIR::Ids.new }

  def make_ops
    const = build.constant(value: 10, dtype: :integer, as: :const, ids: ids)
    input = build.load_input(key: "x", dtype: :integer, as: :val, ids: ids)
    mul = build.kernel_call(function: "core.mul", args: %i[const val], out_dtype: :integer, as: :result, ids: ids)
    yld = build.yield(result_register: :result)
    [const, input, mul, yld]
  end

  let(:initial_state) do
    ops_by_decl = { "demo" => { operations: make_ops } }
    Kumi::Core::Analyzer::AnalysisState.new.with(:lir_module, ops_by_decl)
  end

  it "replaces constant register operands with immediate placeholders" do
    pass = described_class.new(schema, initial_state)
    new_state = pass.run([])
    new_ops = new_state[:lir_module]["demo"][:operations]

    kernel = new_ops[2]
    expect(kernel.inputs.first).to eq(:__immediate_placeholder__)
    expect(kernel.inputs.last).to eq(:val)

    literal = kernel.immediates.first
    expect(literal.value).to eq(10)
    expect(new_state[:lir_06_const_prop]).to eq(new_state[:lir_module])
  end
end
