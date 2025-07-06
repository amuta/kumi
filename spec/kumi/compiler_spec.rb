RSpec.describe Kumi::Compiler do
  include Kumi::ASTFactory # gives us `syntax`

  # Operator stubs for the test
  let(:schema) do
    a = attr(:a, lit(2))
    b = attr(:b, call(:add, binding_ref(:a), lit(3)))
    syntax(:schema, [a, b], [])
  end

  let(:analysis) { Kumi::Analyzer.analyze!(schema) }
  let(:exec)     { Kumi::Compiler.compile(schema, analyzer: analysis) }

  # Expectations
  it "returns an Kumi::CompiledSchema" do
    expect(exec).to be_a(Kumi::CompiledSchema)
  end

  it "computes attributes in a single evaluation pass" do
    result = exec.evaluate({})               # empty data context
    expect(result[:attributes][:b]).to eq 5  # (2 + 3)
  end

  it "evaluates traits independently" do
    # separate schema: single trait adult? (age >= 18)
    t_schema = syntax(
      :schema,
      [],
      [trait(:adult, call(:>=, field(:age), lit(18)))]
    )
    t_exec = Kumi::Compiler.compile(
      t_schema,
      analyzer: Kumi::Analyzer.analyze!(t_schema)
    )

    traits_only = t_exec.traits(age: 20)
    expect(traits_only[:adult]).to be true
  end
end
