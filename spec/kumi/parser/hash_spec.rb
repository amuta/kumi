RSpec.describe "ValueDeclaration with HashExpressions" do
  context "When parsing values with hashes" do
    module HashValueSchema
      extend Kumi::Schema

      build_syntax_tree do
        input do
          string :name
          string :state
        end

        value :data, {
          key_name: input.name,
          key_state: input.state
        }
      end
    end

    it "builds HashExpressions" do
      ast = HashValueSchema.__syntax_tree__

      expect(ast.inputs.length).to eq(2)
      expect(ast.values.length).to eq(1)

      val_decl = ast.values.first
      expect(val_decl.expression).to be_a(Kumi::Syntax::HashExpression)

      hash_expr = val_decl.expression

      pair1, pair2 = hash_expr.pairs
      expect(pair1.size).to eq(2)
      expect(pair2.size).to eq(2)

      expect(pair1[0]).to be_a(Kumi::Syntax::Literal)
      expect(pair1[0].value).to eq(:key_name)

      expect(pair1[1]).to be_a(Kumi::Syntax::InputReference)
      expect(pair1[1].name).to eq(:name)

      expect(pair2[0]).to be_a(Kumi::Syntax::Literal)
      expect(pair2[0].value).to eq(:key_state)

      expect(pair2[1]).to be_a(Kumi::Syntax::InputReference)
      expect(pair2[1].name).to eq(:state)
    end
  end
end
