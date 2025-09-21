# frozen_string_literal: true

module ArrayMaxSugar
  extend Kumi::Schema

  schema do
    input do
      float :income
      float :std_deduction
    end

    value :taxable_income, fn(:max, [input.income - input.std_deduction, 0])
  end
end

RSpec.describe "Sugar syntax array max operations" do
  describe "array_max_sugar schema" do
    context "with positive taxable income" do
      it "calculates taxable income correctly when income exceeds deduction" do
        data = { income: 50_000.0, std_deduction: 12_000.0 }
        runner = ArrayMaxSugar.from(data)

        expect(runner[:taxable_income]).to eq(38_000.0)
      end

      it "handles small positive differences" do
        data = { income: 15_000.0, std_deduction: 14_999.0 }
        runner = ArrayMaxSugar.from(data)

        expect(runner[:taxable_income]).to eq(1.0)
      end
    end

    context "with zero or negative taxable income" do
      it "returns zero when deduction equals income" do
        data = { income: 12_000.0, std_deduction: 12_000.0 }
        runner = ArrayMaxSugar.from(data)

        expect(runner[:taxable_income]).to eq(0.0)
      end

      it "returns zero when deduction exceeds income" do
        data = { income: 8_000.0, std_deduction: 12_000.0 }
        runner = ArrayMaxSugar.from(data)

        expect(runner[:taxable_income]).to eq(0.0)
      end

      it "returns zero for negative income with positive deduction" do
        data = { income: -5_000.0, std_deduction: 12_000.0 }
        runner = ArrayMaxSugar.from(data)

        expect(runner[:taxable_income]).to eq(0.0)
      end
    end

    context "with edge cases" do
      it "handles zero income and zero deduction" do
        data = { income: 0.0, std_deduction: 0.0 }
        runner = ArrayMaxSugar.from(data)

        expect(runner[:taxable_income]).to eq(0.0)
      end

      it "handles negative deduction (credit)" do
        data = { income: 50_000.0, std_deduction: -5_000.0 }
        runner = ArrayMaxSugar.from(data)

        expect(runner[:taxable_income]).to eq(55_000.0)
      end

      it "handles very large numbers" do
        data = { income: 1_000_000.0, std_deduction: 250_000.0 }
        runner = ArrayMaxSugar.from(data)

        expect(runner[:taxable_income]).to eq(750_000.0)
      end
    end
  end
end
