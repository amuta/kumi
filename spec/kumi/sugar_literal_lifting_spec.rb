# frozen_string_literal: true

module LiteralLiftingSugar
  extend Kumi::Schema

  schema do
    input do
      float :value
      integer :count
    end

    # Integer literals on left side
    value :int_plus, 5 + input.count
    value :int_multiply, 3 * input.count

    # Float literals on left side
    value :float_plus, 5.5 + input.value
    value :float_multiply, 2.5 * input.value

    # Comparison with literals on left
    trait :int_greater, input.count < 10
    trait :int_equal, input.count == 7
    trait :float_equal, input.value == 7.5
  end
end

RSpec.describe "Sugar syntax literal lifting operations" do
  describe "literal_lifting_sugar schema" do
    it "automatically lifts numeric literals to Literal nodes" do
      data = { value: 7.5, count: 7 }
      runner = LiteralLiftingSugar.from(data)

      # Integer arithmetic
      expect(runner[:int_plus]).to eq(12)
      expect(runner[:int_multiply]).to eq(21)

      # Float arithmetic
      expect(runner[:float_plus]).to eq(13.0)
      expect(runner[:float_multiply]).to eq(18.75)

      # Comparisons
      expect(runner[:int_greater]).to be true
      expect(runner[:int_equal]).to be true
      expect(runner[:float_equal]).to be true
    end

    it "handles different literal values" do
      data = { value: 10.0, count: 15 }
      runner = LiteralLiftingSugar.from(data)

      expect(runner[:int_plus]).to eq(20)
      expect(runner[:int_multiply]).to eq(45)
      expect(runner[:float_plus]).to eq(15.5)
      expect(runner[:float_multiply]).to eq(25.0)
      expect(runner[:int_greater]).to be false
      expect(runner[:int_equal]).to be false
      expect(runner[:float_equal]).to be false
    end

    it "handles zero and negative literals" do
      data = { value: 0.0, count: -3 }
      runner = LiteralLiftingSugar.from(data)

      expect(runner[:int_plus]).to eq(2)
      expect(runner[:int_multiply]).to eq(-9)
      expect(runner[:float_plus]).to eq(5.5)
      expect(runner[:float_multiply]).to eq(0.0)
      expect(runner[:int_greater]).to be true
    end
  end
end
