# frozen_string_literal: true

RSpec.describe Kumi::Compiler do
  include ASTFactory # gives us `syntax`

  # Operator stubs for the test
  let(:schema) do
    a = attr(:a, lit(2))
    b = attr(:b, call(:add, binding_ref(:a), lit(3)))
    syntax(:root, [], [a, b], [])
  end

  let(:analysis) { Kumi::Analyzer.analyze!(schema) }
  let(:exec)     { described_class.compile(schema, analyzer: analysis) }

  # Expectations
  it "returns an Kumi::CompiledSchema" do
    expect(exec).to be_a(Kumi::CompiledSchema)
  end

  it "computes values in a single evaluation pass" do
    result = exec.evaluate({}) # empty data context
    expect(result[:b]).to eq 5 # (2 + 3)
  end

  it "lazyly evaluates values" do
    schema = begin
      a = attr(:a, field_ref(:x))
      b = attr(:b, call(:add, binding_ref(:a), field_ref(:y)))
      syntax(:root, [], [a, b], [])
    end

    # We will test this by putting a bad value that will only cause an error
    # when we try to evaluate `:b`
    exec = described_class.compile(schema, analyzer: analysis)
    context = { x: 10, y: "bad_input" }
    expect { exec.evaluate(context, :a) }.not_to raise_error
    expect { exec.evaluate(context, :b) }.to raise_error(Kumi::Errors::RuntimeError, /Error calling fn\(:add/)
  end

  it "evaluates traits independently" do
    # separate schema: single trait adult? (age >= 18)
    t_schema = syntax(
      :root,
      [field_decl(:age)],
      [],
      [trait(:adult, call(:>=, field_ref(:age), lit(18)))]
    )
    t_exec = described_class.compile(
      t_schema,
      analyzer: Kumi::Analyzer.analyze!(t_schema)
    )

    traits_only = t_exec.traits(age: 20)
    expect(traits_only[:adult]).to be true
  end
end
