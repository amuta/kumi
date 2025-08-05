# frozen_string_literal: true

RSpec.describe Kumi::Core::Analyzer::Passes::SemanticConstraintValidator do
  include ASTFactory

  let(:state) { Kumi::Core::Analyzer::AnalysisState.new }
  let(:errors) { [] }

  def run(schema)
    described_class.new(schema, state).run(errors)
  end

  describe "#run" do
    context "with valid trait expressions" do
      let(:schema) do
        valid_trait = trait(:adult, call(:>=, input_ref(:age), lit(18)))
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
        cascade_attr = attr(:grade, syntax(:cascade_expr, [
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
        cascade_attr = attr(:grade, syntax(:cascade_expr, [
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
        cascade_attr = attr(:grade, syntax(:cascade_expr, [
                                             when_case_expression(call(:>=, input_ref(:score), lit(90)), lit("A"))
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
        cascade_attr = attr(:grade, syntax(:cascade_expr, [
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
        calc_attr = attr(:total, call(:add, input_ref(:a), input_ref(:b)))
        syntax(:root, [], [calc_attr], [], loc: loc)
      end

      it "passes validation" do
        run(schema)
        expect(errors).to be_empty
      end
    end

    context "with invalid function calls" do
      let(:schema) do
        invalid_attr = attr(:result, call(:unknown_function, input_ref(:input)))
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
        cascade_attr = attr(:grade, syntax(:cascade_expr, [
                                             when_case_expression(input_ref(:score), lit("A")) # Naked field ref - should be rejected
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
        bad_cascade = attr(:grade, syntax(:cascade_expr, [
                                            when_case_expression(input_ref(:score), lit("A")) # Naked field ref
                                          ], loc: loc))
        bad_function = attr(:result, call(:nonexistent_fn))
        bad_trait = trait(:bad_trait, input_ref(:some_field))

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

    context "with valid element() usage" do
      let(:schema) do
        # Valid: primitive element without children
        primitive_array = input_decl(:flags, :array, nil, children: [], access_mode: :element)

        # Valid: 2D array - array of arrays where inner arrays contain primitives
        nested_array = input_decl(:grid, :array, nil, children: [
                                    input_decl(:row, :array, nil, children: [], access_mode: :element)
                                  ], access_mode: :element)

        # Valid: object element with children
        object_array = input_decl(:items, :array, nil, children: [
                                    input_decl(:name, :string, nil),
                                    input_decl(:value, :integer, nil)
                                  ], access_mode: :object)

        syntax(:root, [primitive_array, nested_array, object_array], [], [], loc: loc)
      end

      it "passes validation" do
        run(schema)
        expect(errors).to be_empty
      end
    end

    context "with valid array declarations" do
      let(:schema) do
        # Valid: element access mode array
        element_array = input_decl(:flags, :array, nil, children: [
                                     input_decl(:active, :boolean, nil)
                                   ], access_mode: :element)

        # Valid: object access mode array
        object_array = input_decl(:items, :array, nil, children: [
                                    input_decl(:name, :string, nil),
                                    input_decl(:value, :integer, nil)
                                  ], access_mode: :object)

        # Valid: nested array structure
        nested_array = input_decl(:grid, :array, nil, children: [
                                    input_decl(:row, :array, nil, children: [
                                                 input_decl(:cell, :boolean, nil)
                                               ], access_mode: :element)
                                  ], access_mode: :element)

        syntax(:root, [element_array, object_array, nested_array], [], [], loc: loc)
      end

      it "passes validation for valid array structures" do
        run(schema)
        expect(errors).to be_empty
      end
    end

    context "with invalid multiple element declarations" do
      let(:schema) do
        # Invalid: element access mode array with multiple children
        invalid_array = input_decl(:mixed, :array, nil, children: [
                                     input_decl(:active, :boolean, nil),
                                     input_decl(:status, :string, nil)
                                   ], access_mode: :element)

        syntax(:root, [invalid_array], [], [], loc: loc)
      end

      it "reports semantic error for multiple element children" do
        run(schema)
        expect(errors.size).to eq(1)
        expect(errors.first.to_s).to include("array with access_mode :element can only have one direct child element")
        expect(errors.first.to_s).to include("but found 2 children")
      end
    end
  end
end
