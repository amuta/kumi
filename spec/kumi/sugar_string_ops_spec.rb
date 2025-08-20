# frozen_string_literal: true

RSpec.describe "Sugar syntax string operations" do
  include SchemaFixtureHelper
  
  let(:schema) do
    require_schema("string_ops_sugar")
    StringOpsSugar
  end

  describe "string_ops_sugar schema" do
    it "supports string equality operations" do
      data = { name: "John" }
      runner = schema.from(data)

      expect(runner[:is_john]).to be true
      expect(runner[:not_jane]).to be true
      expect(runner[:inverted_check]).to be false
    end

    it "handles different names correctly" do
      data = { name: "Jane" }
      runner = schema.from(data)

      expect(runner[:is_john]).to be false
      expect(runner[:not_jane]).to be false
      expect(runner[:inverted_check]).to be false
    end

    it "handles Alice specifically" do
      data = { name: "Alice" }
      runner = schema.from(data)

      expect(runner[:is_john]).to be false
      expect(runner[:not_jane]).to be true
      expect(runner[:inverted_check]).to be true
    end

    it "handles empty and special strings" do
      data = { name: "" }
      runner = schema.from(data)

      expect(runner[:is_john]).to be false
      expect(runner[:not_jane]).to be true
      expect(runner[:inverted_check]).to be false
    end

    it "handles case sensitivity" do
      data = { name: "john" }
      runner = schema.from(data)

      expect(runner[:is_john]).to be false
      expect(runner[:not_jane]).to be true
      expect(runner[:inverted_check]).to be false
    end
  end
end