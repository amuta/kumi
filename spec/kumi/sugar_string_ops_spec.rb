# frozen_string_literal: true

module StringOpsSugar
  extend Kumi::Schema
  
  schema do
    input do
      string :name
    end

    # String equality (only supported operation)
    trait :is_john, input.name == "John"
    trait :not_jane, input.name != "Jane"
    trait :inverted_check, input.name == "Alice"
  end
end

RSpec.describe "Sugar syntax string operations" do
  describe "string_ops_sugar schema" do
    it "supports string equality operations" do
      data = { name: "John" }
      runner = StringOpsSugar.from(data)

      expect(runner[:is_john]).to be true
      expect(runner[:not_jane]).to be true
      expect(runner[:inverted_check]).to be false
    end

    it "handles different names correctly" do
      data = { name: "Jane" }
      runner = StringOpsSugar.from(data)

      expect(runner[:is_john]).to be false
      expect(runner[:not_jane]).to be false
      expect(runner[:inverted_check]).to be false
    end

    it "handles Alice specifically" do
      data = { name: "Alice" }
      runner = StringOpsSugar.from(data)

      expect(runner[:is_john]).to be false
      expect(runner[:not_jane]).to be true
      expect(runner[:inverted_check]).to be true
    end

    it "handles empty and special strings" do
      data = { name: "" }
      runner = StringOpsSugar.from(data)

      expect(runner[:is_john]).to be false
      expect(runner[:not_jane]).to be true
      expect(runner[:inverted_check]).to be false
    end

    it "handles case sensitivity" do
      data = { name: "john" }
      runner = StringOpsSugar.from(data)

      expect(runner[:is_john]).to be false
      expect(runner[:not_jane]).to be true
      expect(runner[:inverted_check]).to be false
    end
  end
end