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
  it "returns an Kumi::Runtime::Program" do
    expect(exec).to be_a(Kumi::Runtime::Program)
  end

  it "computes values in a single evaluation pass" do
    result = exec.evaluate({}) # empty data context
    expect(result[:b]).to eq 5 # (2 + 3)
  end

  it "lazyly evaluates values" do
    schema = syntax(:root,
                    [
                      input_decl(:x, :integer),
                      input_decl(:y, :any)
                    ],
                    [
                      attr(:a, input_ref(:x)),
                      attr(:b, call(:add, ref(:a), input_ref(:y)))
                    ],
                    [])

    analysis = Kumi::Analyzer.analyze!(schema)
    exec = described_class.compile(schema, analyzer: analysis)

    context = { x: 10, y: "bad_input" }
    expect { exec.evaluate(context, :a) }.not_to raise_error
    expect { exec.evaluate(context, :b) }.to raise_error(RuntimeError, /:add/)
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

    result = t_exec.evaluate(age: 20)
    expect(result[:adult]).to be true
  end
end
