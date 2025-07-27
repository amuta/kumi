# frozen_string_literal: true

RSpec.describe "Sugar syntax array max operations" do
  describe "array_max_sugar schema" do
    context "with positive taxable income" do
      it "calculates taxable income correctly when income exceeds deduction" do
        data = { income: 50_000.0, std_deduction: 12_000.0 }
        runner = run_sugar_schema(:array_max_sugar, data)

        expect(runner[:taxable_income]).to eq(38_000.0)
      end

      it "handles small positive differences" do
        data = { income: 15_000.0, std_deduction: 14_999.0 }
        runner = run_sugar_schema(:array_max_sugar, data)

        expect(runner[:taxable_income]).to eq(1.0)
      end
    end

    context "with zero or negative taxable income" do
      it "returns zero when deduction equals income" do
        data = { income: 12_000.0, std_deduction: 12_000.0 }
        runner = run_sugar_schema(:array_max_sugar, data)

        expect(runner[:taxable_income]).to eq(0.0)
      end

      it "returns zero when deduction exceeds income" do
        data = { income: 8_000.0, std_deduction: 12_000.0 }
        runner = run_sugar_schema(:array_max_sugar, data)

        expect(runner[:taxable_income]).to eq(0.0)
      end

      it "returns zero for negative income with positive deduction" do
        data = { income: -5_000.0, std_deduction: 12_000.0 }
        runner = run_sugar_schema(:array_max_sugar, data)

        expect(runner[:taxable_income]).to eq(0.0)
      end
    end

    context "with edge cases" do
      it "handles zero income and zero deduction" do
        data = { income: 0.0, std_deduction: 0.0 }
        runner = run_sugar_schema(:array_max_sugar, data)

        expect(runner[:taxable_income]).to eq(0.0)
      end

      it "handles negative deduction (credit)" do
        data = { income: 50_000.0, std_deduction: -5_000.0 }
        runner = run_sugar_schema(:array_max_sugar, data)

        expect(runner[:taxable_income]).to eq(55_000.0)
      end

      it "handles very large numbers" do
        data = { income: 1_000_000.0, std_deduction: 250_000.0 }
        runner = run_sugar_schema(:array_max_sugar, data)

        expect(runner[:taxable_income]).to eq(750_000.0)
      end
    end

    context "using expect_sugar_schema helper" do
      it "provides block-based assertions" do
        expect_sugar_schema(:array_max_sugar, { income: 75_000.0, std_deduction: 25_000.0 }) do |result|
          expect(result[:taxable_income]).to eq(50_000.0)
        end
      end
    end
  end
end
