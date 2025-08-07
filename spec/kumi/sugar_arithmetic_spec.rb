# frozen_string_literal: true

module ArithmeticSugar
  extend Kumi::Schema
  
  schema do
    input do
      float :a
      float :b
      integer :x
      integer :y
    end

    value :sum, input.a + input.b
    value :difference, input.a - input.b
    value :product, input.x * input.y
    value :quotient, input.a / input.b
    value :modulo, input.x % input.y
    value :power, input.x**input.y
    value :unary_minus, -input.a
  end
end

RSpec.describe "Sugar syntax arithmetic operations" do
  describe "arithmetic_sugar schema" do
    it "performs all arithmetic operations correctly" do
      data = { a: 10.0, b: 3.0, x: 7, y: 2 }
      runner = ArithmeticSugar.from(data)

      expect(runner[:sum]).to eq(13.0)
      expect(runner[:difference]).to eq(7.0)
      expect(runner[:product]).to eq(14)
      expect(runner[:quotient]).to be_within(0.001).of(3.333)
      expect(runner[:modulo]).to eq(1)
      expect(runner[:power]).to eq(49)
      expect(runner[:unary_minus]).to eq(-10.0)
    end

    it "handles zero and negative values" do
      data = { a: -5.0, b: 0.0, x: -3, y: 4 }
      runner = ArithmeticSugar.from(data)

      expect(runner[:sum]).to eq(-5.0)
      expect(runner[:difference]).to eq(-5.0)
      expect(runner[:product]).to eq(-12)
      expect(runner[:unary_minus]).to eq(5.0)
    end

    it "handles edge cases" do
      data = { a: 100.0, b: 1.0, x: 2, y: 10 }
      runner = ArithmeticSugar.from(data)

      expect(runner[:quotient]).to eq(100.0)
      expect(runner[:power]).to eq(1024)
      expect(runner[:modulo]).to eq(2)
    end
  end
end