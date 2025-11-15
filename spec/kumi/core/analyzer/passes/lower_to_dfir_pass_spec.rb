# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kumi::Core::Analyzer::Passes::LowerToDFIRPass do
  let(:int_type) { ir_types.scalar(:integer) }

  it "stores DF modules in analysis state" do
    snast = snast_factory.build do |b|
      const = snast_factory.const(1, dtype: int_type)
      b.declaration(:one, axes: [], dtype: int_type) { const }
    end

    state = Kumi::Core::Analyzer::AnalysisState.new(
      snast_module: snast,
      registry: double(:registry, resolve_function: :"core.add"),
      input_table: {},
      input_metadata: {},
      imported_schemas: {}
    )

    pass = described_class.new(nil, state)
    new_state = pass.run([])

    expect(new_state[:df_module]).to be_a(Kumi::IR::DF::Graph)
    expect(new_state[:df_module_unoptimized]).to be_a(Kumi::IR::DF::Graph)
    expect(new_state[:df_module].functions).not_to be_empty
  end
end
