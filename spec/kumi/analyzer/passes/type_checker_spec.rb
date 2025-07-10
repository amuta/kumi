# frozen_string_literal: true

RSpec.describe Kumi::Analyzer::Passes::TypeChecker do
  include ASTFactory

  let(:state)  { {} }
  let(:errors) { [] }

  def run(schema)
    # The TypeChecker runs after the NameIndexer to have access to all definitions.
    Kumi::Analyzer::Passes::NameIndexer.new(schema, state).run(errors)
    described_class.new(schema, state).run(errors)
  end

  describe ".run" do
    context "when operator arity mismatch" do
      let(:schema) do
        # Create a schema where a function is called with the wrong number of arguments.
        # FunctionRegistry's :> operator expects 2 arguments.
        bad = trait(:bad, call(:>, lit(1)))
        syntax(:root, [], [bad])
      end

      it "records an arity error" do
        run(schema)
        expect(errors.first.last).to match(/expects 2 args, got 1/)
      end
    end

    context "when operator type mismatch" do
      let(:schema) do
        # Create a schema where a function is called with the wrong type of argument.
        # The :> operator expects numeric arguments.
        bad = trait(:bad, call(:>, lit(1), lit("test")))
        syntax(:root, [], [bad])
      end

      it "records a type error for the mismatched argument" do
        run(schema)
        expect(errors.first.last).to match(/expects numeric, got literal `test` of type string/)
      end
    end

    context "when a function call is valid" do
      let(:schema) do
        valid = trait(:valid, call(:>=, lit(10), lit(5)))
        syntax(:root, [], [valid])
      end

      it "completes with no errors" do
        run(schema)
        expect(errors).to be_empty
      end
    end

    context "when an unknown function is called" do
      let(:schema) do
        bad = trait(:bad, call(:unknown_function, lit(1)))
        syntax(:root, [], [bad])
      end

      it "records an unsupported operator error" do
        run(schema)
        expect(errors.first.last).to match(/unsupported operator `unknown_function`/)
      end
    end
  end
end
