# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Additional UnsatDetector Constraint Types" do
  describe "type incompatibility constraints" do
    it "detects impossible comparison between integer and string fields" do
      expect do
        build_schema do
          input do
            integer :age
            string :name
          end

          trait :age_equals_name, input.age, :==, input.name

          value :result do
            on :age_equals_name, "Impossible type comparison"
            base "Normal"
          end
        end
      end.to raise_error(Kumi::Errors::SemanticError, /impossible/)
    end

    it "detects impossible comparison between different typed literals" do
      expect do
        build_schema do
          input {}

          value :number, 42
          value :text, "hello"
          trait :number_equals_text, number, :==, text

          value :result do
            on :number_equals_text, "Impossible"
            base "Normal"
          end
        end
      end.to raise_error(Kumi::Errors::SemanticError, /impossible/)
    end

    it "allows comparison between same types" do
      expect do
        build_schema do
          input do
            integer :age1
            integer :age2
          end

          trait :ages_equal, input.age1, :==, input.age2

          value :result do
            on :ages_equal, "Same type comparison"
            base "Normal"
          end
        end
      end.not_to raise_error
    end
  end

  describe "range/bounds violations through mathematical operations" do
    it "detects impossible bounds after mathematical operations" do
      expect do
        build_schema do
          input do
            integer :value, domain: 1..10
          end

          value :doubled, fn(:multiply, input.value, 2) # range: 2..20
          trait :impossible_bound, doubled, :>, 25 # impossible since max is 20

          value :result do
            on :impossible_bound, "Impossible bound"
            base "Normal"
          end
        end
      end.to raise_error(Kumi::Errors::SemanticError, /impossible/)
    end

    it "detects impossible negative results from positive domain" do
      expect do
        build_schema do
          input do
            integer :positive, domain: 1..100
          end

          value :still_positive, fn(:add, input.positive, 5)  # range: 6..105
          trait :impossible_negative, still_positive, :<, 0   # impossible

          value :result do
            on :impossible_negative, "Impossible negative"
            base "Normal"
          end
        end
      end.to raise_error(Kumi::Errors::SemanticError, /impossible/)
    end

    it "allows valid bounds after mathematical operations" do
      expect do
        build_schema do
          input do
            integer :value, domain: 1..10
          end

          value :doubled, fn(:multiply, input.value, 2) # range: 2..20
          trait :valid_bound, doubled, :>, 15 # possible since max is 20

          value :result do
            on :valid_bound, "Valid bound"
            base "Normal"
          end
        end
      end.not_to raise_error
    end
  end

  describe "string operations with known constraints" do
    it "detects impossible string concatenation results" do
      expect do
        build_schema do
          input do
            string :prefix, domain: %w[user admin]
          end

          value :full_name, fn(:concat, input.prefix, "_role")
          trait :impossible_suffix, full_name, :==, "guest_role" # impossible

          value :result do
            on :impossible_suffix, "Impossible suffix"
            base "Normal"
          end
        end
      end.to raise_error(Kumi::Errors::SemanticError, /impossible/)
    end

    it "allows valid string concatenation results" do
      expect do
        build_schema do
          input do
            string :prefix, domain: %w[user admin]
          end

          value :full_name, fn(:concat, input.prefix, "_role")
          trait :valid_suffix, full_name, :==, "user_role"  # possible

          value :result do
            on :valid_suffix, "Valid suffix"
            base "Normal"
          end
        end
      end.not_to raise_error
    end
  end

  describe "contradictory boolean logic" do
    it "detects logically impossible boolean combinations" do
      expect do
        build_schema do
          input do
            boolean :is_active
          end

          trait :active, input.is_active, :==, true
          trait :inactive, input.is_active, :==, false
          trait :contradictory, fn(:and, active, inactive)  # logically impossible

          value :result do
            on :contradictory, "Impossible logic"
            base "Normal"
          end
        end
      end.to raise_error(Kumi::Errors::SemanticError, /impossible/)
    end

    it "detects impossible boolean field contradictions" do
      expect do
        build_schema do
          input do
            boolean :flag
          end

          trait :is_true, input.flag, :==, true
          trait :is_false, input.flag, :==, false

          value :result do
            on :is_true, :is_false, "Both true and false" # impossible
            base "Normal"
          end
        end
      end.to raise_error(Kumi::Errors::SemanticError, /impossible/)
    end

    it "allows valid boolean logic" do
      expect do
        build_schema do
          input do
            boolean :is_active
            boolean :is_verified
          end

          trait :active, input.is_active, :==, true
          trait :verified, input.is_verified, :==, true
          trait :both, fn(:and, active, verified) # possible

          value :result do
            on :both, "Both active and verified"
            base "Normal"
          end
        end
      end.not_to raise_error
    end
  end

  describe "literal value contradictions" do
    it "detects contradictory literal assignments" do
      expect do
        build_schema do
          input {}

          value :status, "active"
          trait :is_inactive, status, :==, "inactive" # impossible

          value :result do
            on :is_inactive, "Impossible"
            base "Normal"
          end
        end
      end.to raise_error(Kumi::Errors::SemanticError, /impossible/)
    end

    it "detects contradictory numeric literals" do
      expect do
        build_schema do
          input {}

          value :count, 42
          trait :is_zero, count, :==, 0 # impossible

          value :result do
            on :is_zero, "Impossible"
            base "Normal"
          end
        end
      end.to raise_error(Kumi::Errors::SemanticError, /impossible/)
    end

    it "allows valid literal comparisons" do
      expect do
        build_schema do
          input {}

          value :status, "active"
          trait :is_active, status, :==, "active" # valid

          value :result do
            on :is_active, "Valid"
            base "Normal"
          end
        end
      end.not_to raise_error
    end
  end

  describe "complex dependency chain impossibilities" do
    it "detects impossibilities through mixed mathematical and domain chains" do
      expect do
        build_schema do
          input do
            integer :base, domain: 1..5
          end

          value :step1, fn(:multiply, input.base, 2) # range: 2..10
          value :step2, fn(:add, step1, 3)           # range: 5..13
          value :final, step2

          trait :impossible_high, final, :>, 20      # impossible since max is 13

          value :result do
            on :impossible_high, "Impossible through chain"
            base "Normal"
          end
        end
      end.to raise_error(Kumi::Errors::SemanticError, /impossible/)
    end

    it "detects domain violations through complex transformations" do
      expect do
        build_schema do
          input do
            string :category, domain: %w[basic premium]
          end

          value :category_copy, input.category
          value :category_upper, fn(:concat, category_copy, "_TIER")
          value :final_category, category_upper

          trait :is_enterprise, final_category, :==, "enterprise_TIER" # impossible

          value :result do
            on :is_enterprise, "Impossible transformation"
            base "Normal"
          end
        end
      end.to raise_error(Kumi::Errors::SemanticError, /impossible/)
    end
  end
end
