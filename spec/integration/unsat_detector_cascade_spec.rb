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
            on x_lt_100, y_gt_1000, "Impossible"
            base "Default"
          end
        end
      end.to raise_error(Kumi::Errors::SemanticError, /conjunction `x_lt_100 AND y_gt_1000` is impossible/)
    end

    it "detects impossible conditions through deep dependency chains" do
      expect do
        build_schema do
          input do
            integer :base_value
          end

          # Build a deep dependency chain: val0 = base + 0, val1 = val0 + 1, val2 = val1 + 1, etc.
          value :val0, fn(:add, input.base_value, 0)
          value :val1, fn(:add, val0, 1)
          value :val2, fn(:add, val1, 1)
          value :val3, fn(:add, val2, 1)
          value :val4, fn(:add, val3, 1)
          value :val5, fn(:add, val4, 1)

          # Create contradictory traits on the same deep value
          trait :val5_gt_100, val5, :>, 100  # val5 > 100
          trait :val5_lt_50, val5, :<, 50    # val5 < 50 (impossible if val5 > 100)

          value :deep_result do
            on val5_gt_100, val5_lt_50, "Impossible Combination"
            base "Valid"
          end
        end
      end.to raise_error(Kumi::Errors::SemanticError, /conjunction `val5_gt_100 AND val5_lt_50` is impossible/)
    end

    it "detects mathematical impossibilities across dependency chains with enhanced solver" do
      expect do
        build_schema do
          input do
            integer :base
          end

          # Build a simple chain where relationships are mathematically constrained
          value :derived_value, fn(:add, input.base, 10) # derived = base + 10

          # These constraints are mathematically impossible:
          # If base == 50, then derived == 60, so derived == 40 is impossible
          # The enhanced solver should detect this cross-variable relationship
          trait :base_is_50, input.base, :==, 50
          trait :derived_is_40, derived_value, :==, 40

          value :result do
            on base_is_50, derived_is_40, "Mathematical Impossibility"
            base "Valid"
          end
        end
      end.to raise_error(Kumi::Errors::SemanticError, /conjunction `base_is_50 AND derived_is_40` is impossible/)
    end

    it "detects impossibilities through multi-step dependency chains with iterative propagation" do
      # Enhanced solver can now chain multiple relationships together using iterative propagation
      expect do
        build_schema do
          input do
            integer :start
          end

          # Build a longer chain: start -> step1 -> step2 -> final
          value :step1, fn(:add, input.start, 5)  # step1 = start + 5
          value :step2, fn(:multiply, step1, 2)   # step2 = (start + 5) * 2 = 2*start + 10
          value :final, fn(:subtract, step2, 3)   # final = 2*start + 10 - 3 = 2*start + 7

          # If start == 10, then final == 27
          # So final == 20 is impossible when start == 10
          # Enhanced solver should now detect this through iterative propagation
          trait :start_is_10, input.start, :==, 10
          trait :final_is_20, final, :==, 20

          value :chain_result do
            on start_is_10, final_is_20, "Multi-step mathematical impossibility"
            base "Valid"
          end
        end
      end.to raise_error(Kumi::Errors::SemanticError, /conjunction `start_is_10 AND final_is_20` is impossible/)
    end

    it "detects contradictions with subtraction operations" do
      expect do
        build_schema do
          input do
            integer :x
          end

          value :y, fn(:subtract, input.x, 15) # y = x - 15

          # If x == 20, then y == 5
          # So y == 10 is impossible when x == 20
          trait :x_is_20, input.x, :==, 20
          trait :y_is_10, y, :==, 10

          value :subtract_result do
            on x_is_20, y_is_10, "Impossible"
            base "Valid"
          end
        end
      end.to raise_error(Kumi::Errors::SemanticError, /conjunction `x_is_20 AND y_is_10` is impossible/)
    end

    it "detects impossibilities in deep dependency chains like the benchmark example" do
      # Based on the deep_schema_compilation_and_evaluation_benchmark.rb pattern
      # Build a deep chain similar to: v0 = seed, v1 = v0 + 1, v2 = v1 + 2, etc.
      expect do
        build_schema do
          input do
            integer :seed
          end

          # Build dependency chain: v0 = seed, v1 = v0 + 1, v2 = v1 + 2, etc.
          value :v0, input.seed
          value :v1, fn(:add, v0, 1)
          value :v2, fn(:add, v1, 2)
          value :v3, fn(:add, v2, 3)
          value :v4, fn(:add, v3, 4)
          value :v5, fn(:add, v4, 5)

          # If seed == 0, then v5 = 0 + 1 + 2 + 3 + 4 + 5 = 15
          # So v5 == 10 is impossible when seed == 0
          trait :seed_is_zero, input.seed, :==, 0
          trait :v5_is_ten, v5, :==, 10

          value :deep_chain_result do
            on seed_is_zero, v5_is_ten, "Deep chain impossibility"
            base "Valid"
          end
        end
      end.to raise_error(Kumi::Errors::SemanticError, /conjunction `seed_is_zero AND v5_is_ten` is impossible/)
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
            on high_performer, "Exceptional"       # Check: is high_performer satisfiable? YES
            on avg_performer, "Satisfactory"       # Check: is avg_performer satisfiable? YES
            on poor_performer, "Needs Improvement" # Check: is poor_performer satisfiable? YES
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
          on high_performer, "Exceptional"
          on poor_performer, "Needs Improvement"
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
            on young, "Young Adult"      # age < 30 (satisfiable)
            on senior, "Senior"          # age >= 65 (satisfiable)
            on middle, "Middle Aged"     # age >= 30 (satisfiable)
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
        on high_performer, "Exceptional"
        on poor_performer, "Needs Improvement"
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
            on very_young, very_old, "Impossible" # Combining these is impossible
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
            on young_and_old, "Impossible Combination" # young AND old is impossible
            on other_impossible, "Also Impossible" # another impossible trait
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
            on young_and_old, "Impossible Combination" # young AND old is impossible
            on other_impossible, "Also Impossible"     # another impossible trait
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
            on small, "Small Amount"
            on large, "Large Amount"
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
            on low_bracket, fn(:multiply, taxable_income, 0.10)
            on mid_bracket, fn(:add, 1_100, fn(:multiply, fn(:subtract, taxable_income, 11_000), 0.12))
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
            on premium, "Premium Category"
            on small, "Small Amount"
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
            on low, "Bronze"
            on high, "Gold"
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
            on single, "Single Filer"
            on married, "Married Filing Jointly"
            on divorced, "Head of Household"
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
          on single, "Single Filer"
          on married, "Married Filing Jointly"
          on divorced, "Head of Household"
          base "Unknown Status"
        end
      end

      single_result = runner.from(status: "single")
      expect(single_result[:filing_status]).to eq("Single Filer")

      married_result = runner.from(status: "married")
      expect(married_result[:filing_status]).to eq("Married Filing Jointly")
    end
  end

  describe "complex cascade with multiple conditions" do
    it "detects impossible conjunctions in cascade conditions" do
      expect do
        build_schema do
          input do
            string :weapon_type, domain: %w[sword dagger bow staff]
          end

          trait :has_weapon, input.weapon_type, :!=, "fists"
          trait :ranged_weapon, input.weapon_type, :==, "bow"
          trait :magic_weapon, input.weapon_type, :==, "staff"

          value :total_weapon_damage do
            on ranged_weapon, magic_weapon, 99 # its impossible
            on has_weapon, 10
            base 2
          end
        end
      end.to raise_error(Kumi::Errors::SemanticError, /conjunction `ranged_weapon AND magic_weapon` is impossible/)
    end
  end

  describe "cascade logic with disjunctive conditions" do
    it "allows on_any conditions with mutually exclusive traits" do
      expect do
        build_schema do
          input do
            string :role, domain: %w[staff admin guest]
          end

          trait :is_staff, input.role, :==, "staff"
          trait :is_admin, input.role, :==, "admin"
          trait :is_guest, input.role, :==, "guest"

          value :permission_level do
            on_any is_staff, is_admin, "Full Access"
            on is_guest, "Read-Only"
            base "No Access"
          end
        end
      end.not_to raise_error
    end

    it "allows on_none conditions with mutually exclusive traits" do
      expect do
        build_schema do
          input do
            string :role, domain: %w[staff admin guest]
          end

          trait :is_staff, input.role, :==, "staff"
          trait :is_admin, input.role, :==, "admin"

          value :permission_level do
            on_any is_staff, is_admin, "Full Access"
            on_none is_staff, is_admin, "Read-Only"
            base "No Access"
          end
        end
      end.not_to raise_error
    end

    it "detects impossible conjunctions only in on (all?) conditions, not any? or none?" do
      expect do
        build_schema do
          input do
            string :weapon_type, domain: %w[sword dagger bow staff]
          end

          trait :ranged_weapon, input.weapon_type, :==, "bow"
          trait :magic_weapon, input.weapon_type, :==, "staff"

          value :damage do
            # This should fail - impossible conjunction with on (all?)
            on ranged_weapon, magic_weapon, 99
            base 1
          end
        end
      end.to raise_error(Kumi::Errors::SemanticError, /conjunction `ranged_weapon AND magic_weapon` is impossible/)
    end

    it "reports specific trait names in error messages, not declaration names" do
      error = nil
      begin
        build_schema do
          input do
            string :status, domain: %w[active inactive suspended]
          end

          trait :active_user, input.status, :==, "active"
          trait :inactive_user, input.status, :==, "inactive"
          trait :suspended_user, input.status, :==, "suspended"

          value :user_permissions do
            on active_user, inactive_user, "Limited Access" # Impossible
            on suspended_user, "No Access"
            base "Unknown"
          end
        end
      rescue Kumi::Errors::SemanticError => e
        error = e
      end

      expect(error).not_to be_nil
      expect(error.message).to include("conjunction `active_user AND inactive_user` is impossible")
      expect(error.message).not_to include("user_permissions")
    end
  end

  describe "set membership impossibilities" do
    it "detects impossible trait when value is constrained to set that excludes trait condition" do
      expect do
        build_schema do
          input do
            string :status, domain: %w[pending approved]
          end

          value :fixed_status, "rejected"
          trait :is_approved, fixed_status, :==, "approved"

          value :result do
            on is_approved, "This is impossible"
            base "Normal"
          end
        end
      end.to raise_error(Kumi::Errors::SemanticError, /conjunction `is_approved` is impossible/)
    end

    it "detects impossible conjunction when trait checks value outside input domain" do
      expect do
        build_schema do
          input do
            string :category, domain: %w[basic premium]
          end

          trait :is_enterprise, input.category, :==, "enterprise"
          trait :is_basic, input.category, :==, "basic"

          value :access_level do
            on is_enterprise, is_basic, "Impossible combination"
            base "Normal"
          end
        end
      end.to raise_error(Kumi::Errors::SemanticError, /conjunction `is_enterprise AND is_basic` is impossible/)
    end

    it "detects impossible trait when value reference violates domain through dependency chain" do
      expect do
        build_schema do
          input do
            string :role, domain: %w[user admin]
          end

          value :the_role, input.role
          trait :is_guest, the_role, :==, "guest"

          value :permissions do
            on is_guest, "Guest permissions"
            base "User permissions"
          end
        end
      end.to raise_error(Kumi::Errors::SemanticError, /conjunction `is_guest` is impossible/)
    end

    it "allows valid trait conditions within input domain" do
      expect do
        build_schema do
          input do
            string :status, domain: %w[active inactive suspended]
          end

          trait :is_active, input.status, :==, "active"
          trait :is_suspended, input.status, :==, "suspended"

          value :access_level do
            on is_active, "Full access"
            on is_suspended, "No access"
            base "Limited access"
          end
        end
      end.not_to raise_error
    end
  end
end
