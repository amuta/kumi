# frozen_string_literal: true

RSpec.describe "Unsatisfiable‑conjunction detector" do
  context "strict inequality cycles" do
    it "detects 3-element cycle: x > y > z > x" do
      expect do
        Kumi.schema do
          input do
            key :x, type: :integer
            key :y, type: :integer
            key :z, type: :integer
          end

          trait :x_gt_y, input.x, :>, input.y
          trait :y_gt_z, input.y, :>, input.z
          trait :z_gt_x, input.z, :>, input.x

          value :impossible, fn(:all?, [ref(:x_gt_y), ref(:y_gt_z), ref(:z_gt_x)])
        end
      end.to raise_error(Kumi::Errors::SemanticError, /logically impossible|unsatisfiable/i)
    end

    it "detects 2-element cycle: x > y > x" do
      expect do
        Kumi.schema do
          input do
            key :x, type: :integer
            key :y, type: :integer
          end

          trait :x_gt_y, input.x, :>, input.y
          trait :y_gt_x, input.y, :>, input.x

          value :impossible, fn(:all?, [ref(:x_gt_y), ref(:y_gt_x)])
        end
      end.to raise_error(Kumi::Errors::SemanticError, /logically impossible|unsatisfiable/i)
    end

    it "detects 4-element cycle: a > b > c > d > a" do
      expect do
        Kumi.schema do
          input do
            key :a, type: :integer
            key :b, type: :integer
            key :c, type: :integer
            key :d, type: :integer
          end

          trait :a_gt_b, input.a, :>, input.b
          trait :b_gt_c, input.b, :>, input.c
          trait :c_gt_d, input.c, :>, input.d
          trait :d_gt_a, input.d, :>, input.a

          value :impossible, fn(:all?, [ref(:a_gt_b), ref(:b_gt_c), ref(:c_gt_d), ref(:d_gt_a)])
        end
      end.to raise_error(Kumi::Errors::SemanticError, /logically impossible|unsatisfiable/i)
    end
  end

  context "mixed inequality cycles" do
    it "detects cycle with mixed > and < operators: x > y, z < y, z > x" do
      expect do
        Kumi.schema do
          input do
            key :x, type: :integer
            key :y, type: :integer
            key :z, type: :integer
          end

          trait :x_gt_y, input.x, :>, input.y
          trait :z_lt_y, input.z, :<, input.y # equivalent to y > z
          trait :z_gt_x, input.z, :>, input.x

          value :impossible, fn(:all?, [ref(:x_gt_y), ref(:z_lt_y), ref(:z_gt_x)])
        end
      end.to raise_error(Kumi::Errors::SemanticError, /logically impossible|unsatisfiable/i)
    end

    it "detects contradiction: x > y and y > x" do
      expect do
        Kumi.schema do
          input do
            key :x, type: :integer
            key :y, type: :integer
          end

          trait :x_gt_y, input.x, :>, input.y
          trait :y_gt_x, input.y, :>, input.x

          value :contradiction, fn(:all?, [ref(:x_gt_y), ref(:y_gt_x)])
        end
      end.to raise_error(Kumi::Errors::SemanticError, /logically impossible|unsatisfiable/i)
    end
  end

  context "indirect cycles through traits" do
    it "detects cycle when traits reference other traits" do
      expect do
        Kumi.schema do
          input do
            key :x, type: :integer
            key :y, type: :integer
            key :z, type: :integer
          end

          trait :x_gt_y, input.x, :>, input.y
          trait :y_gt_z, input.y, :>, input.z
          trait :z_gt_x, input.z, :>, input.x

          # Trait that combines others
          value :chain_xy_yz, fn(:all?, [ref(:x_gt_y), ref(:y_gt_z)])

          value :impossible, fn(:all?, [ref(:chain_xy_yz), ref(:z_gt_x)])
        end
      end.to raise_error(Kumi::Errors::SemanticError, /logically impossible|unsatisfiable/i)
    end
  end

  context "constants in comparisons" do
    it "detects contradiction with constants: x > 10 and x < 5" do
      expect do
        Kumi.schema do
          input do
            key :x, type: :integer
          end

          trait :x_gt_10, input.x, :>, 10
          trait :x_lt_5, input.x, :<, 5

          value :impossible, fn(:all?, [ref(:x_gt_10), ref(:x_lt_5)])
        end
      end.to raise_error(Kumi::Errors::SemanticError, /logically impossible|unsatisfiable/i)
    end

    it "detects contradiction: 5 > x and x > 10" do
      expect do
        Kumi.schema do
          input do
            key :x, type: :integer
          end

          trait :five_gt_x, 5, :>, input.x
          trait :x_gt_10, input.x, :>, 10

          value :impossible, fn(:all?, [ref(:five_gt_x), ref(:x_gt_10)])
        end
      end.to raise_error(Kumi::Errors::SemanticError, /logically impossible|unsatisfiable/i)
    end
  end

  context "satisfiable cases" do
    it "allows satisfiable chain: x > y > z" do
      expect do
        Kumi.schema do
          input do
            key :x, type: :integer
            key :y, type: :integer
            key :z, type: :integer
          end

          trait :x_gt_y, input.x, :>, input.y
          trait :y_gt_z, input.y, :>, input.z

          value :valid_chain, fn(:all?, [ref(:x_gt_y), ref(:y_gt_z)])
        end
      end.not_to raise_error
    end

    it "allows satisfiable constraints with constants: x > 10 and x < 20" do
      expect do
        Kumi.schema do
          input do
            key :x, type: :integer
          end

          trait :x_gt_10, input.x, :>, 10
          trait :x_lt_20, input.x, :<, 20

          value :valid_range, fn(:all?, [ref(:x_gt_10), ref(:x_lt_20)])
        end
      end.not_to raise_error
    end

    it "allows non-connected comparisons" do
      expect do
        Kumi.schema do
          input do
            key :a, type: :integer
            key :b, type: :integer
            key :x, type: :integer
            key :y, type: :integer
          end

          trait :a_gt_b, input.a, :>, input.b
          trait :x_gt_y, input.x, :>, input.y

          value :independent, fn(:all?, [ref(:a_gt_b), ref(:x_gt_y)])
        end
      end.not_to raise_error
    end

    it "allows partial chains that don't form cycles" do
      expect do
        Kumi.schema do
          input do
            key :x, type: :integer
            key :y, type: :integer
            key :z, type: :integer
            key :w, type: :integer
          end

          trait :x_gt_y, input.x, :>, input.y
          trait :y_gt_z, input.y, :>, input.z
          trait :w_gt_z, input.w, :>, input.z

          value :partial_chain, fn(:all?, [ref(:x_gt_y), ref(:y_gt_z), ref(:w_gt_z)])
        end
      end.not_to raise_error
    end
  end

  context "complex scenarios" do
    it "detects contradictions in deeply nested trait references" do
      expect do
        Kumi.schema do
          input do
            key :a, type: :integer
            key :b, type: :integer
            key :c, type: :integer
          end

          trait :a_gt_b, input.a, :>, input.b
          trait :b_gt_c, input.b, :>, input.c
          value :chain_ab_bc, fn(:all?, [ref(:a_gt_b), ref(:b_gt_c)])

          trait :c_gt_a, input.c, :>, input.a
          value :impossible_nested, fn(:all?, [ref(:chain_ab_bc), ref(:c_gt_a)])
        end
      end.to raise_error(Kumi::Errors::SemanticError, /logically impossible|unsatisfiable/i)
    end

    it "allows complex but satisfiable constraint networks" do
      expect do
        Kumi.schema do
          input do
            key :w, type: :integer
            key :x, type: :integer
            key :y, type: :integer
            key :z, type: :integer
          end

          # Create a tree structure: w > x, w > y, x > z, y > z
          trait :w_gt_x, input.w, :>, input.x
          trait :w_gt_y, input.w, :>, input.y
          trait :x_gt_z, input.x, :>, input.z
          trait :y_gt_z, input.y, :>, input.z

          value :tree_structure, fn(:all?, [ref(:w_gt_x), ref(:w_gt_y), ref(:x_gt_z), ref(:y_gt_z)])
        end
      end.not_to raise_error
    end

    it "handles multiple equality constraints correctly" do
      expect do
        Kumi.schema do
          input do
            key :a, type: :integer
            key :b, type: :integer
            key :c, type: :integer
          end

          trait :a_eq_b, input.a, :==, input.b
          trait :b_eq_c, input.b, :==, input.c
          # Don't explicitly state a_eq_c, let it be derived

          value :all_equal, fn(:all?, [ref(:a_eq_b), ref(:b_eq_c)])
        end
      end.not_to raise_error
    end

    it "detects contradiction with mixed equality and inequality" do
      expect do
        Kumi.schema do
          input do
            key :x, type: :integer
            key :y, type: :integer
            key :z, type: :integer
          end

          trait :x_eq_y, input.x, :==, input.y
          trait :y_eq_z, input.y, :==, input.z
          trait :x_gt_z, input.x, :>, input.z # Contradicts transitivity of equality

          value :mixed_contradiction, fn(:all?, [ref(:x_eq_y), ref(:y_eq_z), ref(:x_gt_z)])
        end
      end.to raise_error(Kumi::Errors::SemanticError, /logically impossible|unsatisfiable/i)
    end
  end

  context "value cascades and dependencies" do
    it "detects impossible conditions in cascade logic" do
      expect do
        Kumi.schema do
          input do
            key :age, type: :integer
            key :score, type: :integer
          end

          trait :young, input.age, :<, 25
          trait :old, input.age, :>, 65
          trait :high_score, input.score, :>, 90

          # This cascade condition should be impossible
          value :eligibility do
            on :young, :old, :high_score, "impossible" # age < 25 AND age > 65 is impossible
            on :high_score, "eligible"
            base "not_eligible"
          end
        end
      end.to raise_error(Kumi::Errors::SemanticError, /logically impossible|unsatisfiable/i)
    end

    it "detects contradictory traits in complex cascade chains" do
      expect do
        Kumi.schema do
          input do
            key :temperature, type: :integer
            key :pressure, type: :integer
          end

          trait :hot, input.temperature, :>, 80
          trait :cold, input.temperature, :<, 20
          trait :high_pressure, input.pressure, :>, 100
          trait :low_pressure, input.pressure, :<, 50

          # Multiple impossible combinations
          value :system_state do
            on :hot, :cold, "impossible_temp" # temp > 80 AND temp < 20
            on :high_pressure, :low_pressure, "impossible_pressure" # pressure > 100 AND pressure < 50
            on :hot, :high_pressure, "normal"
            base "unknown"
          end
        end
      end.to raise_error(Kumi::Errors::SemanticError, /logically impossible|unsatisfiable/i)
    end

    it "detects impossible combinations on the same variable" do
      expect do
        Kumi.schema do
          input do
            key :user_age, type: :integer
            key :experience_years, type: :integer
          end

          trait :child, input.user_age, :<, 16
          trait :adult, input.user_age, :>, 65
          trait :has_experience, input.experience_years, :>, 5

          # Impossible: same age variable cannot be both < 16 AND > 65
          value :profile_type do
            on :child, :adult, "impossible_age" # age < 16 AND age > 65
            on :adult, :has_experience, "experienced_adult"
            base "normal"
          end
        end
      end.to raise_error(Kumi::Errors::SemanticError, /logically impossible|unsatisfiable/i)
    end

    it "allows satisfiable cascade conditions with overlapping ranges" do
      expect do
        Kumi.schema do
          input do
            key :score, type: :integer
            key :bonus, type: :integer
          end

          trait :good_score, input.score, :>=, 70
          trait :excellent_score, input.score, :>=, 90
          trait :has_bonus, input.bonus, :>, 0

          value :grade do
            on :excellent_score, :has_bonus, "A+"
            on :excellent_score, "A"
            on :good_score, :has_bonus, "B+"
            on :good_score, "B"
            base "C"
          end
        end
      end.not_to raise_error
    end

    it "detects impossible conditions with computed values on same expression" do
      expect do
        Kumi.schema do
          input do
            key :total, type: :integer
          end

          # Same expression with contradictory constraints
          trait :total_large, input.total, :>, 100
          trait :total_small, input.total, :<, 50

          value :analysis do
            on :total_large, :total_small, "impossible_total" # total > 100 AND total < 50
            on :total_large, "large"
            base "normal"
          end
        end
      end.to raise_error(Kumi::Errors::SemanticError, /logically impossible|unsatisfiable/i)
    end

    it "handles complex business logic scenarios correctly" do
      expect do
        Kumi.schema do
          input do
            key :customer_age, type: :integer
            key :account_balance, type: :float
            key :credit_score, type: :integer
          end

          trait :minor, input.customer_age, :<, 18
          trait :high_balance, input.account_balance, :>, 10_000.0
          trait :excellent_credit, input.credit_score, :>, 800
          trait :poor_credit, input.credit_score, :<, 500

          value :loan_eligibility do
            # Valid combinations
            on :high_balance, :excellent_credit, "pre_approved"
            on :excellent_credit, "eligible"

            # This should be caught as potentially impossible -
            # minors typically can't have both high balances and excellent credit
            on :minor, :high_balance, :excellent_credit, "exceptional_minor"

            # This is impossible - same credit score can't be both > 800 and < 500
            on :excellent_credit, :poor_credit, "impossible_credit"

            base "not_eligible"
          end
        end
      end.to raise_error(Kumi::Errors::SemanticError, /logically impossible|unsatisfiable/i)
    end
  end

  context "realistic business scenarios" do
    it "detects impossible conditions in loan approval rules" do
      expect do
        Kumi.schema do
          input do
            key :credit_score, type: :integer
            key :annual_income, type: :float
            key :employment_status, type: :float
          end

          # Credit score traits
          trait :excellent_credit, input.credit_score, :>, 800
          trait :poor_credit, input.credit_score, :<, 500
          trait :good_credit, input.credit_score, :>, 700

          # Income traits
          trait :high_income, input.annual_income, :>, 100_000.0
          trait :low_income, input.annual_income, :<, 30_000.0

          # Employment traits
          trait :employed, input.employment_status, :==, "employed"
          trait :unemployed, input.employment_status, :==, "unemployed"

          # Loan approval logic with impossible combinations
          value :loan_approval do
            # Impossible: same credit score cannot be both > 800 and < 500
            on :excellent_credit, :poor_credit, "impossible_credit_contradiction"

            # Impossible: same employment status cannot be both employed and unemployed
            on :employed, :unemployed, :high_income, "impossible_employment_contradiction"

            # Valid combinations
            on :excellent_credit, :high_income, :employed, "pre_approved"
            on :good_credit, :employed, "approved"
            on :poor_credit, :high_income, "conditional"

            base "denied"
          end
        end
      end.to raise_error(Kumi::Errors::SemanticError, /logically impossible|unsatisfiable/i)
    end

    it "detects impossible fraud risk scoring combinations" do
      expect do
        Kumi.schema do
          input do
            key :transaction_amount, type: :float
            key :user_account_age_days, type: :integer
            key :device_trust_score, type: :integer
          end

          # Transaction amount traits
          trait :micro_transaction, input.transaction_amount, :<, 10.0
          trait :large_transaction, input.transaction_amount, :>, 1000.0

          # Account age traits
          trait :new_account, input.user_account_age_days, :<, 30
          trait :established_account, input.user_account_age_days, :>, 365

          # Device trust traits
          trait :trusted_device, input.device_trust_score, :>, 80
          trait :suspicious_device, input.device_trust_score, :<, 20

          # Fraud risk assessment with logical contradictions
          value :risk_level do
            # Impossible: transaction amount cannot be both < 10 and > 1000
            on :micro_transaction, :large_transaction, "impossible_amount"

            # Impossible: account cannot be both new (< 30 days) and established (> 365 days)
            on :new_account, :established_account, "impossible_account_age"

            # Impossible: device cannot be both trusted (> 80) and suspicious (< 20)
            on :trusted_device, :suspicious_device, "impossible_device_trust"

            # Valid risk combinations
            on :large_transaction, :new_account, :suspicious_device, "high_risk"
            on :micro_transaction, :trusted_device, "low_risk"
            on :established_account, :trusted_device, "low_risk"

            base "medium_risk"
          end
        end
      end.to raise_error(Kumi::Errors::SemanticError, /logically impossible|unsatisfiable/i)
    end

    it "allows complex but logically consistent business rules" do
      expect do
        Kumi.schema do
          input do
            key :customer_tier, type: :float
            key :purchase_amount, type: :float
            key :loyalty_points, type: :integer
          end

          # Customer tier traits
          trait :vip_customer, input.customer_tier, :==, "VIP"
          trait :premium_customer, input.customer_tier, :==, "Premium"
          trait :standard_customer, input.customer_tier, :==, "Standard"

          # Purchase traits
          trait :large_purchase, input.purchase_amount, :>, 500.0
          trait :small_purchase, input.purchase_amount, :<, 50.0

          # Loyalty traits
          trait :high_loyalty, input.loyalty_points, :>, 1000
          trait :low_loyalty, input.loyalty_points, :<, 100

          # Discount calculation - all combinations are logically possible
          value :discount_percentage do
            on :vip_customer, :large_purchase, 15.0
            on :vip_customer, :high_loyalty, 12.0
            on :premium_customer, :large_purchase, :high_loyalty, 10.0
            on :premium_customer, :large_purchase, 8.0
            on :standard_customer, :high_loyalty, 5.0
            on :large_purchase, 3.0
            on :high_loyalty, 2.0
            base 0.0
          end
        end
      end.not_to raise_error
    end
  end

  context "non-strict inequalities" do
    it "detects impossible non-strict inequality combinations" do
      expect do
        Kumi.schema do
          input do
            key :age, type: :integer
          end

          trait :child, input.age, :<, 16
          trait :adult, input.age, :>=, 18

          value :category do
            on :child, :adult, "impossible" # age < 16 AND age >= 18
            on :child, "child"
            on :adult, "adult"
            base "teen"
          end
        end
      end.to raise_error(Kumi::Errors::SemanticError, /logically impossible|unsatisfiable/i)
    end

    it "detects gap contradictions" do
      expect do
        Kumi.schema do
          input do
            key :score, type: :integer
          end

          trait :low_score, input.score, :<=, 50
          trait :high_score, input.score, :>, 80

          value :grade do
            on :low_score, :high_score, "impossible" # score <= 50 AND score > 80
            on :high_score, "A"
            base "B"
          end
        end
      end.to raise_error(Kumi::Errors::SemanticError, /logically impossible|unsatisfiable/i)
    end

    it "detects boundary contradictions" do
      expect do
        Kumi.schema do
          input do
            key :value, type: :integer
          end

          trait :below_threshold, input.value, :<, 100
          trait :at_or_above_threshold, input.value, :>=, 100

          value :status do
            on :below_threshold, :at_or_above_threshold, "impossible" # value < 100 AND value >= 100
            on :below_threshold, "below"
            base "above"
          end
        end
      end.to raise_error(Kumi::Errors::SemanticError, /logically impossible|unsatisfiable/i)
    end

    it "allows overlapping non-strict ranges" do
      expect do
        Kumi.schema do
          input do
            key :temperature, type: :integer
          end

          trait :not_too_cold, input.temperature, :>=, 10
          trait :not_too_hot, input.temperature, :<=, 30

          value :comfort do
            on :not_too_cold, :not_too_hot, "comfortable"  # temp >= 10 AND temp <= 30 (valid range [10,30])
            on :not_too_cold, "warm_enough"
            base "too_cold"
          end
        end
      end.not_to raise_error
    end

    it "allows same boundary with compatible operators" do
      expect do
        Kumi.schema do
          input do
            key :limit, type: :integer
          end

          trait :at_most_100, input.limit, :<=, 100
          trait :at_least_100, input.limit, :>=, 100

          value :boundary_check do
            on :at_most_100, :at_least_100, "exactly_100"  # limit <= 100 AND limit >= 100 (limit = 100)
            on :at_most_100, "under_limit"
            base "over_limit"
          end
        end
      end.not_to raise_error
    end

    it "detects mixed strict and non-strict contradictions" do
      expect do
        Kumi.schema do
          input do
            key :number, type: :integer
          end

          trait :strictly_less, input.number, :<, 50
          trait :greater_or_equal, input.number, :>=, 50

          value :mixed_check do
            on :strictly_less, :greater_or_equal, "impossible" # number < 50 AND number >= 50
            base "valid"
          end
        end
      end.to raise_error(Kumi::Errors::SemanticError, /logically impossible|unsatisfiable/i)
    end
  end

  context "edge cases" do
    it "ignores contradictory non-strict cycles" do
      expect do
        Kumi.schema do
          input do
            key :x, type: :integer
            key :y, type: :integer
            key :z, type: :integer
          end

          trait :x_gte_y, input.x, :>=, input.y
          trait :y_gte_z, input.y, :>=, input.z
          trait :z_gte_x, input.z, :>=, input.x

          value :non_strict_cycle, fn(:all?, [ref(:x_gte_y), ref(:y_gte_z), ref(:z_gte_x)])
        end
      end.not_to raise_error # >= allows equality, so this is satisfiable
    end

    it "handles empty conjunction" do
      expect do
        Kumi.schema do
          input do
            key :x, type: :integer
          end

          value :empty_all, fn(:all?, [])
        end
      end.not_to raise_error
    end

    it "handles single comparison" do
      expect do
        Kumi.schema do
          input do
            key :x, type: :integer
            key :y, type: :integer
          end

          trait :x_gt_y, input.x, :>, input.y
          value :single, ref(:x_gt_y)
        end
      end.not_to raise_error
    end

    it "handles equality comparisons" do
      expect do
        Kumi.schema do
          input do
            key :x, type: :integer
            key :y, type: :integer
          end

          trait :x_eq_y, input.x, :==, input.y
          trait :x_gt_y, input.x, :>, input.y

          value :contradiction_with_equality, fn(:all?, [ref(:x_eq_y), ref(:x_gt_y)])
        end
      end.to raise_error(Kumi::Errors::SemanticError, /logically impossible|unsatisfiable/i)
    end
  end
end
