# frozen_string_literal: true

require "spec_helper"

RSpec.describe "UnsatDetector Cascade Bug" do
  # These tests demonstrate the bug where UnsatDetector incorrectly flags
  # cascades with mutually exclusive conditions as "logically impossible"

  describe "cascade with mutually exclusive numerical conditions" do
    it "does not flag cascades with non-overlapping ranges as impossible" do
      # This currently fails due to the bug - UnsatDetector incorrectly combines
      # all cascade conditions into one conjunction
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
      end.to raise_error(Kumi::Errors::SemanticError, /conjunction.*is logically impossible/)
    end

    it "flags cascades with multiple impossible traits in one condition" do
      expect do
        build_schema do
          input do
            integer :age, domain: 0..150
          end

          trait :young, input.age, :<, 25
          trait :old, input.age, :>, 65

          # This should be flagged - combining young AND old in one condition is impossible
          value :impossible_combo do
            on :young, :old, "Impossible Combination" # young AND old is impossible
            base "Normal"
          end
        end
      end.to raise_error(Kumi::Errors::SemanticError, /conjunction.*is logically impossible/)
    end

    it "flags cascades combined impossible trait in one condition" do
      pending "The UnsatDetector does catch this case, but it will reference parent traits and not young_and_old directly"
      expect do
        build_schema do
          input do
            integer :age, domain: 0..150
          end

          trait :young, input.age, :<, 25
          trait :old, input.age, :>, 65
          trait :young_and_old, fn(:and, young, old) # This is logically impossible

          # This should be flagged - combining young AND old in one condition is impossible
          value :impossible_combo do
            on :young_and_old, "Impossible Combination" # young AND old is impossible
            base "Normal"
          end
        end
      end.to raise_error(Kumi::Errors::SemanticError, /conjunction `young_and_old` is logically impossible/)
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

  describe "expected behavior after fix" do
    # These tests describe what should happen after we fix the bug

    it "allows numerical cascades with mutually exclusive conditions" do
      # After the fix, this should work
      # skip "This will pass after we fix the UnsatDetector cascade bug"

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
  end
end
