# frozen_string_literal: true

RSpec.describe Kumi::Parser::Dsl do
  def build_schema(&block)
    subject.build_syntax_tree(&block)
  end

  describe ".build_syntax_tree" do
    it "can define values" do
      schema = build_schema do
        value :name, input.first_name
      end

      expect(schema.attributes.size).to eq(1)
      expect(schema.attributes.first).to be_a(Kumi::Syntax::Declarations::Attribute)
      expect(schema.attributes.first.name).to eq(:name)
      expect(schema.attributes.first.expression).to be_a(Kumi::Syntax::TerminalExpressions::FieldRef)
      expect(schema.attributes.first.expression.name).to eq(:first_name)
    end

    it "can define traits" do
      schema = build_schema do
        trait :vip, input.status, :==, "VIP"
      end

      expect(schema.traits.size).to eq(1)
      trait = schema.traits.first
      expect(trait).to be_a(Kumi::Syntax::Declarations::Trait)
      expect(trait.name).to eq(:vip)
      expect(trait.expression).to be_a(Kumi::Syntax::Expressions::CallExpression)
      expect(trait.expression.fn_name).to eq(:==)
      expect(trait.expression.args.size).to eq(2)
      expect(trait.expression.args.first).to be_a(Kumi::Syntax::TerminalExpressions::FieldRef)
      expect(trait.expression.args.last).to be_a(Kumi::Syntax::TerminalExpressions::Literal)
    end

    it "can define multiple values, traits" do
      schema = build_schema do
        value :name, input.first_name
        value :age, input.birth_date

        trait :adult, input.age, :>=, 18
        trait :senior, input.age, :>=, 65

        value :greet, fn(:hello, input.name)
      end

      expect(schema.attributes.size).to eq(3)
      expect(schema.traits.size).to eq(2)

      expect(schema.attributes.map(&:name)).to contain_exactly(:name, :age, :greet)
      expect(schema.traits.map(&:name)).to contain_exactly(:adult, :senior)

      expect(schema.attributes.map { |attr| attr.expression.class }).to contain_exactly(
        Kumi::Syntax::TerminalExpressions::FieldRef,
        Kumi::Syntax::TerminalExpressions::FieldRef,
        Kumi::Syntax::Expressions::CallExpression
      )

      expect(schema.traits.map(&:expression)).to all(be_a(Kumi::Syntax::Expressions::CallExpression))
      expect(schema.traits.map { |x| x.expression.fn_name }).to contain_exactly(:>=, :>=)
      expect(schema.traits.map(&:expression).flat_map(&:args).to_set).to contain_exactly(
        be_a(Kumi::Syntax::TerminalExpressions::FieldRef),
        be_a(Kumi::Syntax::TerminalExpressions::Literal),
        be_a(Kumi::Syntax::TerminalExpressions::Literal)
      )
    end
  end

  describe "schema validation" do
    let(:error_class) { Kumi::Errors::SyntaxError }

    context "when defining names" do
      it "raises an error if a value name is not a symbol" do
        expect do
          build_schema do
            value "name_string", input.first_name
          end
        end.to raise_error(error_class, /The name for 'value' must be a Symbol, got String/)
      end

      it "raises an error if a trait name is not a symbol" do
        expect do
          build_schema do
            trait "not_a_symbol", input.age, :<, 18
          end
        end.to raise_error(error_class, /The name for 'trait' must be a Symbol, got String/)
      end
    end

    context "when defining values" do
      it "raises an error if a value has no expression or block" do
        expect do
          build_schema do
            value :name
          end
        end.to raise_error(error_class, /value 'name' requires an expression or a block/)
      end

      it "raises an error for an invalid expression type" do
        expect do
          build_schema do
            value :name, { some: :hash }
          end
        end.to raise_error(error_class, /Invalid expression/)
      end
    end

    context "when defining traits" do
      it "raises an error if the operator is not a symbol" do
        expect do
          build_schema do
            trait :is_minor, input.age, "not_a_symbol", 18
          end
        end.to raise_error(error_class, /expects a symbol for an operator, got String/)
      end

      it "raises an error if the operator is not supported" do
        expect do
          build_schema do
            trait :unsupported, input.value, :>>, 42
          end
        end.to raise_error(error_class, /unsupported operator `>>`/)
      end

      it "raises an error if a trait has an invalid expression size" do
        expect do
          build_schema do
            trait :invalid_trait, input.value, :==
          end
        end.to raise_error(error_class, /trait 'invalid_trait' requires exactly 3 arguments: lhs, operator, and rhs/)
      end
    end

    context "when using invalid expressions" do
      it "raises an error for unknown expression types in a call" do
        expect do
          build_schema do
            value :my_value, fn(:foo, self)
          end
        end.to raise_error(error_class, /Invalid expression/)
      end

      it "raises an error for unsupported operators" do
        expect do
          build_schema do
            trait :unsupported, input.value, :>>, 42
          end
        end.to raise_error(error_class, /unsupported operator `>>`/)
      end
    end
  end

  describe "syntax validations" do
    context "with value" do
      it "accepts <symbol>, <expression>" do
        schema = build_schema do
          value :name, input.first_name
        end

        expect(schema.attributes.size).to eq(1)
        expect(schema.attributes.first.name).to eq(:name)
        expect(schema.attributes.first.expression).to be_a(Kumi::Syntax::TerminalExpressions::FieldRef)
      end

      it "accepts <symbol> with a block" do
        schema = build_schema do
          value :status do
            on :active, input.active
          end
        end

        expect(schema.attributes.size).to eq(1)
        expect(schema.attributes.first.expression).to be_a(Kumi::Syntax::Expressions::CascadeExpression)
        expect(schema.attributes.first.expression.cases.size).to eq(1)
        cases = schema.attributes.first.expression.cases
        expect(cases.size).to eq(1)
        expect(cases.first).to be_a(Kumi::Syntax::Expressions::WhenCaseExpression)
        expect(cases.first.condition).to be_a(Kumi::Syntax::Expressions::CallExpression)
        expect(cases.first.condition.fn_name).to eq(:all?)
        expect(cases.first.condition.args.size).to eq(1)
        expect(cases.first.condition.args.first).to be_a(Kumi::Syntax::Expressions::ListExpression)
        expect(cases.first.condition.args.first.elements.size).to eq(1)
        expect(cases.first.condition.args.first.elements.first).to be_a(Kumi::Syntax::TerminalExpressions::Binding)
        expect(cases.first.condition.args.first.elements.first.name).to eq(:active)
        expect(cases.first.result).to be_a(Kumi::Syntax::TerminalExpressions::FieldRef)
        expect(cases.first.result.name).to eq(:active)
      end
    end

    context "with cascade cases" do
      let(:schema) do
        build_schema do
          value :status do
            on :active, input.active
            on :verified, input.verified
            base input.base_status
          end
        end
      end
      let(:attribute_expr) { schema.attributes.first.expression }
      let(:first_case) { attribute_expr.cases[0] }
      let(:second_case) { attribute_expr.cases[1] }
      let(:base_case) { attribute_expr.cases[2] }

      it "creates a cascade expression with cases: whencases" do
        expect(attribute_expr).to be_a(Kumi::Syntax::Expressions::CascadeExpression)
        expect(attribute_expr.cases.size).to eq(3)
      end

      it "creates the first case with a condition and result" do
        expect(first_case.condition).to be_a(Kumi::Syntax::Expressions::CallExpression)
        expect(first_case.condition.fn_name).to eq(:all?)
        expect(first_case.condition.args.size).to eq(1)
        expect(first_case.condition.args.first).to be_a(Kumi::Syntax::Expressions::ListExpression)
        expect(first_case.condition.args.first.elements.size).to eq(1)
        expect(first_case.condition.args.first.elements.first).to be_a(Kumi::Syntax::TerminalExpressions::Binding)
        expect(first_case.condition.args.first.elements.first.name).to eq(:active)
        expect(first_case.result).to be_a(Kumi::Syntax::TerminalExpressions::FieldRef)
        expect(first_case.result.name).to eq(:active)
      end

      it "creates the second case with a condition and result" do
        expect(second_case.condition).to be_a(Kumi::Syntax::Expressions::CallExpression)
        expect(second_case.condition.fn_name).to eq(:all?)
        expect(second_case.condition.args.size).to eq(1)
        expect(second_case.condition.args.first).to be_a(Kumi::Syntax::Expressions::ListExpression)
        expect(second_case.condition.args.first.elements.size).to eq(1)
        expect(second_case.condition.args.first.elements.first).to be_a(Kumi::Syntax::TerminalExpressions::Binding)
        expect(second_case.condition.args.first.elements.first.name).to eq(:verified)
        expect(second_case.result).to be_a(Kumi::Syntax::TerminalExpressions::FieldRef)
        expect(second_case.result.name).to eq(:verified)
      end

      it "creates the base case with a condition and result" do
        expect(base_case.condition).to be_a(Kumi::Syntax::TerminalExpressions::Literal)
        expect(base_case.condition.value).to be(true) # Always matches
        expect(base_case.result).to be_a(Kumi::Syntax::TerminalExpressions::FieldRef)
        expect(base_case.result.name).to eq(:base_status)
      end
    end
  end
end
