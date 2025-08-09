# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kumi::Support::SExpressionPrinter do
  describe ".print" do
    it "formats a comprehensive schema AST in S-expression notation" do
      schema_module = Module.new do
        extend Kumi::Schema

        schema do
          input do
            integer :age, domain: 18..65
            string :name
            float :salary
            array :skills do
              string :name
              integer :level
            end
          end

          trait :adult, (input.age >= 18)
          trait :senior, (input.age >= 65)
          trait :experienced, fn(:>, fn(:size, input.skills), 3)

          value :greeting, fn(:concat, "Hello ", input.name)
          value :status do
            on adult, "Adult"
            on senior, "Senior"
            base "Minor"
          end
          value :skill_count, fn(:size, input.skills)
          value :total_experience, fn(:sum, input.skills.level)
        end
      end

      result = described_class.print(schema_module.__syntax_tree__)

      expected_output = "(Root\n  inputs: [\n    (InputDeclaration :age :integer domain: 18..65)\n    (InputDeclaration :name :string)\n    (InputDeclaration :salary :float)\n    (InputDeclaration :skills :array access_mode: :object\n      [\n        (InputDeclaration :name :string)\n        (InputDeclaration :level :integer)\n      ]\n    )\n  ]\n  values: [\n    (ValueDeclaration :greeting\n      (CallExpression :concat\n        (Literal \"Hello \")\n        (InputReference :name)\n      )\n    )\n    (ValueDeclaration :status\n      (CascadeExpression\n        ((CallExpression :cascade_and\n        (DeclarationReference :adult)\n      ) (Literal \"Adult\"))\n        ((CallExpression :cascade_and\n        (DeclarationReference :senior)\n      ) (Literal \"Senior\"))\n        ((Literal true) (Literal \"Minor\"))\n      )\n    )\n    (ValueDeclaration :skill_count\n      (CallExpression :size\n        (InputReference :skills)\n      )\n    )\n    (ValueDeclaration :total_experience\n      (CallExpression :sum\n        (InputElementReference skills.level)\n      )\n    )\n  ]\n  traits: [\n    (TraitDeclaration :adult\n      (CallExpression :>=\n        (InputReference :age)\n        (Literal 18)\n      )\n    )\n    (TraitDeclaration :senior\n      (CallExpression :>=\n        (InputReference :age)\n        (Literal 65)\n      )\n    )\n    (TraitDeclaration :experienced\n      (CallExpression :>\n        (CallExpression :size\n          (InputReference :skills)\n        )\n        (Literal 3)\n      )\n    )\n  ]\n)"

      expect(result).to eq(expected_output)
    end

    it "handles empty arrays and simple literals" do
      literal_node = Kumi::Syntax::Literal.new(42)
      expect(described_class.print(literal_node)).to eq("(Literal 42)")

      empty_array = []
      expect(described_class.print(empty_array)).to eq("[]")

      simple_array = [literal_node]
      expect(described_class.print(simple_array)).to eq(<<~SEXPR.strip)
        [
          (Literal 42)
        ]
      SEXPR
    end
  end
end
