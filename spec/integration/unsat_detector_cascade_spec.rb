# frozen_string_literal: true

require "spec_helper"

RSpec.describe "UnsatDetector Special Cases" do
  describe "deep references" do
    it "do flag deep references as impossible" do
      expect do
        build_schema do
          value :x, 100
          trait :x_lt_100, x, :<, 100
          value :y, fn(:multiply, x, 10)
          trait :y_gt_1000, y, :>, 1000

          value :result do
            on :x_lt_100, :y_gt_1000, "Impossible"
            base "Default"
          end
        end
      end.to raise_error(Kumi::Errors::SemanticError, /conjunction `x_lt_100 AND y_gt_1000` is impossible/)
    end
  end

  describe "cascade with mutually exclusive numerical conditions" do
    it "does not flag cascades with non-overlapping ranges as impossible" do
      expect do
        build_schema do
          input do
            float :score, domain: 0.0..100.0
          end

          # These traits have non-overlapping ranges - perfectly valid individually
          trait :high_performer, input.score, :>=, 90.0 # score >= 90
          trait :avg_performer, input.score, :>=, 60.0 # score >= 60
          trait :poor_performer, input.score, :<, 60.0 # score < 60

          # This cascade should be VALID - each condition is satisfiable individually
          # Only ONE condition will be evaluated at runtime (they're mutually exclusive by design)
          value :performance_category do
            on :high_performer, "Exceptional"       # Check: is high_performer satisfiable? YES
            on :avg_performer, "Satisfactory"       # Check: is avg_performer satisfiable? YES
            on :poor_performer, "Needs Improvement" # Check: is poor_performer satisfiable? YES
            base "Not Evaluated"
          end
        end
      end.not_to raise_error
    end

    it "allows numerical cascades with mutually exclusive conditions" do
      runner = build_schema do
        input do
          float :score, domain: 0.0..100.0
        end

        trait :high_performer, input.score, :>=, 90.0
        trait :poor_performer, input.score, :<, 60.0

        value :performance_category do
          on :high_performer, "Exceptional"
          on :poor_performer, "Needs Improvement"
          base "Average"
        end
      end

      # Should work correctly at runtime
      high_result = runner.from(score: 95.0)
      expect(high_result[:performance_category]).to eq("Exceptional")

      poor_result = runner.from(score: 45.0)
      expect(poor_result[:performance_category]).to eq("Needs Improvement")

      avg_result = runner.from(score: 75.0)
      expect(avg_result[:performance_category]).to eq("Average")
    end

    it "does not flag cascades with overlapping but individually valid ranges" do
      expect do
        build_schema do
          input do
            integer :age, domain: 0..150
          end

          # These ranges don't overlap - each is individually satisfiable
          trait :young, input.age, :<, 30        # age < 30
          trait :middle, input.age, :>=, 30      # age >= 30
          trait :senior, input.age, :>=, 65      # age >= 65 (subset of middle, but still valid)

          # This should be valid - each individual condition can be satisfied
          value :age_group do
            on :young, "Young Adult"      # age < 30 (satisfiable)
            on :senior, "Senior"          # age >= 65 (satisfiable)
            on :middle, "Middle Aged"     # age >= 30 (satisfiable)
            base "Unknown"
          end
        end
      end.not_to raise_error
    end
  end

  it "allows numerical cascades with mutually exclusive conditions" do
    runner = build_schema do
      input do
        float :score, domain: 0.0..100.0
      end

      trait :high_performer, input.score, :>=, 90.0
      trait :poor_performer, input.score, :<, 60.0

      value :performance_category do
        on :high_performer, "Exceptional"
        on :poor_performer, "Needs Improvement"
        base "Average"
      end
    end

    # Should work correctly at runtime
    high_result = runner.from(score: 95.0)
    expect(high_result[:performance_category]).to eq("Exceptional")

    poor_result = runner.from(score: 45.0)
    expect(poor_result[:performance_category]).to eq("Needs Improvement")

    avg_result = runner.from(score: 75.0)
    expect(avg_result[:performance_category]).to eq("Average")
  end

  describe "cascade with genuinely impossible individual conditions" do
    it "flags cascades when individual conditions are impossible" do
      # This should still be caught - the individual condition is impossible
      expect do
        build_schema do
          input do
            integer :age, domain: 0..150
          end

          # Create two separate traits that are impossible together
          trait :very_young, input.age, :<, 25
          trait :very_old, input.age, :>, 65

          # This should be flagged because combining very_young AND very_old is impossible
          value :age_category do
            on :very_young, :very_old, "Impossible" # Combining these is impossible
            base "Normal"
          end
        end
      end.to raise_error(Kumi::Errors::SemanticError, /conjunction `very_young AND very_old` is impossible/)
    end

    it "flags cascades combined impossible traits in multiple conditions" do
      expect do
        build_schema do
          input do
            integer :age, domain: 0..150
          end

          trait :young, input.age, :<, 25
          trait :old, input.age, :>, 65
          trait :young_and_old, fn(:and, young, old) # This is impossible
          trait :other_impossible, fn(:and, young, old) # Another impossible trait

          # This should be flagged - combining young AND old in one condition is impossible
          value :impossible_combo do
            on :young_and_old, "Impossible Combination" # young AND old is impossible
            on :other_impossible, "Also Impossible" # another impossible trait
            base "Normal"
          end
        end
      end.to raise_error(Kumi::Errors::SemanticError,
                         /(conjunction `young_and_old` is impossible|conjunction `other_impossible` is impossible)/)
    end

    it "flags only the impossible traits and not valid parents" do
      expect do
        build_schema do
          input do
            integer :age, domain: 0..150
          end

          trait :young, input.age, :<, 25
          trait :old, input.age, :>, 65
          trait :young_and_old, fn(:and, young, old) # This is impossible
          trait :other_impossible, fn(:and, young, old) # Another impossible trait

          # This should be flagged - combining young AND old in one condition is impossible
          value :impossible_combo do
            on :young_and_old, "Impossible Combination" # young AND old is impossible
            on :other_impossible, "Also Impossible"     # another impossible trait
            base "Normal"
          end
        end
      end.to raise_error(Kumi::Errors::SemanticError) do |e|
        expect(e.message).to match(/conjunction `young_and_old` is impossible/)
        expect(e.message).to match(/conjunction `other_impossible` is impossible/)
        expect(e.message).not_to match(/conjunction `impossible_combo` is impossible/)
      end
    end
  end

  describe "values depending on cascades with mutually exclusive conditions" do
    it "allows values that depend on cascades with mutually exclusive conditions" do
      expect do
        build_schema do
          input do
            integer :amount, domain: 0..Float::INFINITY
          end

          trait :small, input.amount, :<, 100
          trait :large, input.amount, :>=, 100

          value :category do
            on :small, "Small Amount"
            on :large, "Large Amount"
            base "Unknown"
          end

          value :description, fn(:concat, "Category: ", category)
        end
      end.not_to raise_error
    end

    it "handles complex tax calculation with mutually exclusive brackets" do
      expect do
        build_schema do
          input do
            integer :income, domain: 0..Float::INFINITY
            integer :deductions, domain: 0..Float::INFINITY
            integer :dependents, domain: 0..20
          end

          value :taxable_income, fn(:max, [fn(:subtract, input.income, input.deductions), 0])

          trait :low_bracket, taxable_income, :<, 11_000
          trait :mid_bracket, fn(:and,
                                  fn(:>=, taxable_income, 11_000),
                                  fn(:<, taxable_income, 44_725))

          value :federal_tax do
            on :low_bracket, fn(:multiply, taxable_income, 0.10)
            on :mid_bracket, fn(:add, 1_100, fn(:multiply, fn(:subtract, taxable_income, 11_000), 0.12))
            base fn(:add, 5_147, fn(:multiply, fn(:subtract, taxable_income, 44_725), 0.22))
          end

          trait :has_dependents, input.dependents, :>, 0
          value :child_credit, fn(:if, has_dependents, fn(:multiply, input.dependents, 2_000), 0)

          value :total_tax, fn(:max, [fn(:subtract, federal_tax, child_credit), 0])
          value :effective_rate, fn(:divide, total_tax, fn(:max, [input.income, 1]))
        end
      end.not_to raise_error
    end

    it "works fine when traits are not mutually exclusive" do
      expect do
        build_schema do
          input do
            integer :amount, domain: 0..Float::INFINITY
            boolean :is_premium
          end

          trait :small, input.amount, :<, 100
          trait :premium, input.is_premium, :==, true

          value :category do
            on :premium, "Premium Category"
            on :small, "Small Amount"
            base "Standard"
          end

          value :description, fn(:concat, "Category: ", category)
        end
      end.not_to raise_error
    end

    it "handles complex cascade dependencies correctly" do
      expect do
        build_schema do
          input do
            integer :value, domain: 0..Float::INFINITY
          end

          trait :low, input.value, :<, 50
          trait :high, input.value, :>=, 50

          value :tier do
            on :low, "Bronze"
            on :high, "Gold"
            base "Unknown"
          end

          value :display_name, fn(:concat, "Tier: ", tier)
          value :is_premium, fn(:==, tier, "Gold")
          value :discount_rate, fn(:if, is_premium, 0.10, 0.05)
        end
      end.not_to raise_error
    end
  end

  describe "string-based cascades (current workaround)" do
    it "works fine with string equality conditions" do
      # This currently works because string equalities don't trigger the numerical analysis
      expect do
        build_schema do
          input do
            string :status, domain: %w[single married divorced]
          end

          trait :single, input.status, :==, "single"
          trait :married, input.status, :==, "married"
          trait :divorced, input.status, :==, "divorced"

          value :filing_status do
            on :single, "Single Filer"
            on :married, "Married Filing Jointly"
            on :divorced, "Head of Household"
            base "Unknown Status"
          end
        end
      end.not_to raise_error

      # And it should work correctly at runtime
      runner = build_schema do
        input do
          string :status, domain: %w[single married divorced]
        end

        trait :single, input.status, :==, "single"
        trait :married, input.status, :==, "married"
        trait :divorced, input.status, :==, "divorced"

        value :filing_status do
          on :single, "Single Filer"
          on :married, "Married Filing Jointly"
          on :divorced, "Head of Household"
          base "Unknown Status"
        end
      end

      single_result = runner.from(status: "single")
      expect(single_result[:filing_status]).to eq("Single Filer")

      married_result = runner.from(status: "married")
      expect(married_result[:filing_status]).to eq("Married Filing Jointly")
    end
  end
end
