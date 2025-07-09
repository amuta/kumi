RSpec.describe "Kumi Default Functions" do
  describe "core functions" do
    it "works" do
      schema = Kumi::Parser::Dsl.schema do
        value :test_value do
          on :test_predicate, "result"
          base "default"
        end

        predicate :test_predicate, key(:number), :between?, 6, 8
      end

      analyzer = Kumi::Analyzer.analyze!(schema)
      compiled = Kumi::Compiler.compile(schema, analyzer: analyzer)

      data = { number: 7 }

      result = compiled.evaluate(data)

      expect(result[:test_value]).to eq("result")

      data = { number: 5 }
      result = compiled.evaluate(data)
      expect(result[:test_value]).to eq("default")
    end
  end
end
