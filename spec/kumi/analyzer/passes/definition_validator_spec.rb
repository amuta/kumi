# frozen_string_literal: true

RSpec.describe Kumi::Analyzer::Passes::DefinitionValidator do
  include ASTFactory

  let(:state) { {} }
  let(:errors) { [] }

  def run(schema)
    described_class.new(schema, state).run(errors)
  end

  describe ".run" do
    context "with valid attributes" do
      let(:schema) do
        valid_attr = attr(:price, lit(100))
        valid_attr_with_expr = attr(:total, call(:add, lit(10), lit(20)))
        syntax(:root, [], [valid_attr, valid_attr_with_expr], [], loc: loc)
      end

      it "validates successfully with no errors" do
        run(schema)
        expect(errors).to be_empty
      end
    end

    context "with valid traits" do
      let(:schema) do
        valid_trait = trait(:expensive, call(:>, field_ref(:price), lit(100)))
        valid_trait_complex = trait(:eligible, call(:and,
                                                    call(:>, field_ref(:age), lit(18)),
                                                    call(:==, field_ref(:verified), lit(true))))
        syntax(:root, [], [], [valid_trait, valid_trait_complex], loc: loc)
      end

      it "validates successfully with no errors" do
        run(schema)
        expect(errors).to be_empty
      end
    end

    context "with attribute missing expression" do
      let(:schema) do
        # Create an attribute with nil expression
        invalid_attr = syntax(:attribute, :broken, nil, loc: loc)
        syntax(:root, [], [invalid_attr], [], loc: loc)
      end

      it "reports error for missing expression" do
        run(schema)

        expect(errors.size).to eq(1)
        expect(errors.first.message).to match(/attribute `broken` requires an expression/)
      end
    end

    context "with trait containing non-call expression" do
      let(:schema) do
        # Trait with literal instead of call expression
        invalid_trait = trait(:bad_trait, lit(true))
        syntax(:root, [], [], [invalid_trait], loc: loc)
      end

      it "reports error for non-call expression" do
        run(schema)

        expect(errors.size).to eq(1)
        expect(errors.first.message).to match(/trait `bad_trait` must wrap a CallExpression/)
      end
    end

    context "with trait containing field reference" do
      let(:schema) do
        # Trait with field reference instead of call expression
        invalid_trait = trait(:bad_trait, field_ref(:some_field))
        syntax(:root, [], [], [invalid_trait], loc: loc)
      end

      it "reports error for field reference" do
        run(schema)

        expect(errors.size).to eq(1)
        expect(errors.first.message).to match(/trait `bad_trait` must wrap a CallExpression/)
      end
    end

    context "with trait containing binding reference" do
      let(:schema) do
        # Trait with binding reference instead of call expression
        invalid_trait = trait(:bad_trait, ref(:other_trait))
        syntax(:root, [], [], [invalid_trait], loc: loc)
      end

      it "reports error for binding reference" do
        run(schema)

        expect(errors.size).to eq(1)
        expect(errors.first.message).to match(/trait `bad_trait` must wrap a CallExpression/)
      end
    end

    context "with multiple validation errors" do
      let(:schema) do
        broken_attr = syntax(:attribute, :broken_attr, nil, loc: loc)
        broken_trait = trait(:broken_trait, lit(false))
        another_broken_trait = trait(:another_broken, field_ref(:field))

        syntax(:root, [], [broken_attr], [broken_trait, another_broken_trait], loc: loc)
      end

      it "reports all validation errors" do
        run(schema)

        expect(errors.size).to eq(3)

        error_messages = errors.map(&:message)
        expect(error_messages).to include(match(/attribute `broken_attr` requires an expression/))
        expect(error_messages).to include(match(/trait `broken_trait` must wrap a CallExpression/))
        expect(error_messages).to include(match(/trait `another_broken` must wrap a CallExpression/))
      end
    end

    context "with nested expressions in attributes" do
      let(:schema) do
        # Attributes can have any expression type, not just calls
        literal_attr = attr(:literal, lit(42))
        field_attr = attr(:field, field_ref(:user_input))
        ref_attr = attr(:ref, ref(:other_value))
        call_attr = attr(:call, call(:add, lit(1), lit(2)))

        syntax(:root, [], [literal_attr, field_attr, ref_attr, call_attr], [], loc: loc)
      end

      it "allows any expression type in attributes" do
        run(schema)
        expect(errors).to be_empty
      end
    end

    context "with cascade expressions in attributes" do
      let(:schema) do
        # Create a cascade expression manually since the block syntax doesn't work in tests
        case1 = when_case_expression(call(:>, field_ref(:amount), lit(1000)), lit(0.2))
        case2 = when_case_expression(call(:>, field_ref(:amount), lit(500)), lit(0.1))
        default_case = when_case_expression(lit(true), lit(0.05))
        cascade_expr = syntax(:cascade_expression, [case1, case2, default_case], loc: loc)

        cascade_attr = attr(:discount, cascade_expr)
        syntax(:root, [], [cascade_attr], [], loc: loc)
      end

      it "allows cascade expressions in attributes" do
        run(schema)
        expect(errors).to be_empty
      end
    end

    context "with complex nested structure" do
      let(:schema) do
        # Test that validator traverses nested structures correctly
        complex_attr = attr(:complex, call(:if,
                                           call(:and,
                                                call(:>, field_ref(:price), lit(0)),
                                                call(:<=, field_ref(:price), lit(1000))),
                                           call(:multiply, field_ref(:price), lit(1.2)),
                                           lit(0)))

        syntax(:root, [], [complex_attr], [], loc: loc)
      end

      it "validates nested expressions without issues" do
        run(schema)
        expect(errors).to be_empty
      end
    end
  end
end
