# frozen_string_literal: true

RSpec.describe "Kumi Default Functions" do
  describe "core functions" do
    it "compiles and executes basic function calls successfully" do
      syntax_tree = Kumi::Parser::Dsl.build_syntax_tree do
        input do
          key :number, type: Kumi::Types::INT
        end

        value :test_value do
          on test_trait, "result"
          base "default"
        end

        trait :test_trait, input.number, :between?, 6, 8
      end

      analyzer = Kumi::Analyzer.analyze!(syntax_tree)
      compiled = Kumi::Compiler.compile(syntax_tree, analyzer: analyzer)

      data = { number: 7 }

      result = compiled.evaluate(data)

      expect(result[:test_value]).to eq("result")

      data = { number: 5 }
      result = compiled.evaluate(data)
      expect(result[:test_value]).to eq("default")
    end
  end
end
