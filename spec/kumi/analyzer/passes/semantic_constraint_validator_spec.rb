# frozen_string_literal: true

RSpec.describe Kumi::Analyzer::Passes::SemanticConstraintValidator do
  include ASTFactory

  let(:state) { Kumi::Analyzer::AnalysisState.new }
  let(:errors) { [] }

  def run(schema)
    described_class.new(schema, state).run(errors)
  end

  describe "#run" do
    context "with valid trait expressions" do
      let(:schema) do
        valid_trait = trait(:adult, call(:>=, field_ref(:age), lit(18)))
        syntax(:root, [], [], [valid_trait], loc: loc)
      end

      it "passes validation" do
        run(schema)
        expect(errors).to be_empty
      end
    end

    context "with invalid trait expression" do
      let(:schema) do
        invalid_trait = trait(:invalid_trait, lit("not a boolean expression"))
        syntax(:root, [], [], [invalid_trait], loc: loc)
      end

      it "reports semantic error" do
        run(schema)
        expect(errors.size).to eq(1)
        expect(errors.first.to_s).to include("trait `invalid_trait` must have a boolean expression")
      end
    end

    context "with valid cascade conditions" do
      let(:schema) do
        cascade_attr = attr(:grade, syntax(:cascade_expression, [
          when_case_expression(binding_ref(:high_performer), lit("A"))
        ], loc: loc))
        syntax(:root, [], [cascade_attr], [], loc: loc)
      end

      it "passes validation" do
        run(schema)
        expect(errors).to be_empty
      end
    end

    context "with valid cascade condition - literal" do
      let(:schema) do
        cascade_attr = attr(:grade, syntax(:cascade_expression, [
          when_case_expression(lit(true), lit("A"))
        ], loc: loc))
        syntax(:root, [], [cascade_attr], [], loc: loc)
      end

      it "passes validation" do
        run(schema)
        expect(errors).to be_empty
      end
    end

    context "with valid cascade condition - function call" do
      let(:schema) do
        cascade_attr = attr(:grade, syntax(:cascade_expression, [
          when_case_expression(call(:>=, field_ref(:score), lit(90)), lit("A"))
        ], loc: loc))
        syntax(:root, [], [cascade_attr], [], loc: loc)
      end

      it "passes validation" do
        run(schema)
        expect(errors).to be_empty
      end
    end

    context "with valid boolean trait composition in cascade" do
      let(:schema) do
        # Create a simple cascade with just binding refs for now
        cascade_attr = attr(:grade, syntax(:cascade_expression, [
          when_case_expression(binding_ref(:high_performer), lit("A+"))
        ], loc: loc))
        syntax(:root, [], [cascade_attr], [], loc: loc)
      end

      it "passes validation" do
        run(schema)
        expect(errors).to be_empty
      end
    end

    context "with valid function calls" do
      let(:schema) do
        calc_attr = attr(:total, call(:add, field_ref(:a), field_ref(:b)))
        syntax(:root, [], [calc_attr], [], loc: loc)
      end

      it "passes validation" do
        run(schema)
        expect(errors).to be_empty
      end
    end

    context "with invalid function calls" do
      let(:schema) do
        invalid_attr = attr(:result, call(:unknown_function, field_ref(:input)))
        syntax(:root, [], [invalid_attr], [], loc: loc)
      end

      it "reports semantic error" do
        run(schema)
        expect(errors.size).to eq(1)
        expect(errors.first.to_s).to include("unknown function `unknown_function`")
      end
    end

    context "with invalid cascade condition - field reference without comparison" do
      let(:schema) do
        cascade_attr = attr(:grade, syntax(:cascade_expression, [
          when_case_expression(field_ref(:score), lit("A"))  # Naked field ref - should be rejected
        ], loc: loc))
        syntax(:root, [], [cascade_attr], [], loc: loc)
      end

      it "reports semantic error" do
        run(schema)
        expect(errors.size).to eq(1)
        expect(errors.first.to_s).to include("cascade condition must be trait reference")
      end
    end

    context "with multiple semantic errors" do
      let(:schema) do
        bad_cascade = attr(:grade, syntax(:cascade_expression, [
          when_case_expression(field_ref(:score), lit("A"))  # Naked field ref
        ], loc: loc))
        bad_function = attr(:result, call(:nonexistent_fn))
        bad_trait = trait(:bad_trait, field_ref(:some_field))
        
        syntax(:root, [], [bad_cascade, bad_function], [bad_trait], loc: loc)
      end

      it "reports all semantic errors" do
        run(schema)
        expect(errors.size).to eq(3)
        
        error_messages = errors.map(&:to_s)
        expect(error_messages).to include(match(/cascade condition must be trait reference/))
        expect(error_messages).to include(match(/unknown function `nonexistent_fn`/))
        expect(error_messages).to include(match(/trait `bad_trait` must have a boolean expression/))
      end
    end
  end
end