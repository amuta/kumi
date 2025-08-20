# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kumi::Core::Explain, skip: "Refactor" do
  describe ".call" do
    let(:test_schema) do
      Class.new do
        extend Kumi::Schema

        schema do
          input do
            float :income
            float :rate
          end

          value :tax_amount, fn(:multiply, input.income, input.rate)
          value :after_tax, fn(:subtract, input.income, tax_amount)

          trait :high_earner, fn(:>, input.income, 100_000)

          value :status do
            on high_earner, "High Income"
            base "Regular Income"
          end
        end
      end
    end

    let(:inputs) { { income: 120_000, rate: 0.25 } }

    it "explains simple arithmetic expressions" do
      explanation = described_class.call(test_schema, :tax_amount, inputs: inputs)
      expect(explanation).to include("tax_amount = input.income × input.rate = 120 000 × 0.25 => 30 000")
    end

    it "explains binding references" do
      explanation = described_class.call(test_schema, :after_tax, inputs: inputs)
      expect(explanation).to include("after_tax = input.income - tax_amount = 120 000 - (tax_amount = 30 000) => 90 000")
    end

    it "explains trait expressions" do
      explanation = described_class.call(test_schema, :high_earner, inputs: inputs)
      expect(explanation).to include("high_earner = input.income > 100 000 = 120 000 > 100 000 => true")
    end

    it "explains cascade expressions" do
      explanation = described_class.call(test_schema, :status, inputs: inputs)
      expect(explanation).to include("status =")
      expect(explanation).to include("✓ on")
      expect(explanation).to include("High Income")
    end

    context "with piecewise_sum function" do
      let(:piecewise_schema) do
        Class.new do
          extend Kumi::Schema

          schema do
            input do
              float :taxable_income
            end

            value :breaks, [10_000, 50_000, 100_000]
            value :rates, [0.10, 0.20, 0.30]
            value :tax_calc, fn(:piecewise_sum, input.taxable_income, breaks, rates)
            value :total_tax, fn(:at, tax_calc, 0)
          end
        end
      end

      xit "explains piecewise_sum with detailed breakdown" do
        explanation = described_class.call(piecewise_schema, :total_tax,
                                           inputs: { taxable_income: 75_000 })

        expect(explanation).to include("total_tax = at(tax_calc = [16 500, 0.3]")
        expect(explanation).to include("0")
        expect(explanation).to include("=> 16 500")
        expect(explanation).not_to include("0 = 0") # Should not show redundant literal values
      end

      xit "explains the underlying piecewise calculation" do
        explanation = described_class.call(piecewise_schema, :tax_calc,
                                           inputs: { taxable_income: 75_000 })

        expect(explanation).to include("tax_calc = piecewise_sum(input.taxable_income = 75 000")
        expect(explanation).to include("breaks = [10 000, 50 000, 100 000]")
        expect(explanation).to include("rates = [0.1, 0.2, 0.3]")
        expect(explanation).to include("=> [16 500, 0.3]")

        # Check that indentation aligns with opening parenthesis
        lines = explanation.split("\n")
        expect(lines[0]).to start_with("tax_calc = piecewise_sum(")

        # The continuation should align with the opening paren: "tax_calc = piecewise_sum("
        # That's 11 chars for "tax_calc = " + 13 chars for "piecewise_sum(" = 24 chars total
        expected_indent = " " * 24
        expect(lines[1]).to start_with(expected_indent)
        expect(lines[2]).to start_with(expected_indent)
      end
    end

    context "error handling" do
      it "raises error for unknown declaration" do
        expect do
          described_class.call(test_schema, :unknown_field, inputs: inputs)
        end.to raise_error(ArgumentError, /Unknown declaration: unknown_field/)
      end

      it "raises error for uncompiled schema" do
        uncompiled_schema = Class.new { extend Kumi::Schema }

        expect do
          described_class.call(uncompiled_schema, :tax_amount, inputs: inputs)
        end.to raise_error(ArgumentError, /Schema not found or not compiled/)
      end
    end
  end
end
