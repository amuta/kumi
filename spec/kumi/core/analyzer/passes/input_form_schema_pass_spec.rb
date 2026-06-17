# frozen_string_literal: true

RSpec.describe Kumi::Core::Analyzer::Passes::InputFormSchemaPass do
  it "emits an empty object schema for bare hash inputs" do
    schema = Kumi::Syntax::Root.new(
      [Kumi::Syntax::InputDeclaration.new(:metadata, nil, :hash, [], nil)],
      [],
      [],
      []
    )

    result = Kumi::Core::Analyzer::PassManager
             .new([
                    Kumi::Core::Analyzer::Passes::InputCollectorPass,
                    described_class
                  ])
             .run(schema)

    expect(result).to be_succeeded
    expect(result.final_state[:input_form_schema]).to eq(
      metadata: { type: :object, fields: {} }
    )
  end
end
