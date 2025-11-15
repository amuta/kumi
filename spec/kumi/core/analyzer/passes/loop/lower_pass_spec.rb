# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kumi::Core::Analyzer::Passes::Loop::LowerPass do
  let(:float) { ir_types.scalar(:float) }

  it "emits Loop modules and stores them in state" do
    df_module = df_module_with_map
    state = Kumi::Core::Analyzer::AnalysisState.new(df_module:)

    pass = described_class.new(nil, state)
    new_state = pass.run([])

    loop_module = new_state[:loop_module]
    expect(loop_module).to be_a(Kumi::IR::Loop::Module)
    fn = loop_module.fetch_function(:cart_total)
    expect(fn.entry_block.instructions.map(&:opcode)).to include(:yield)
  end
end
