# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Additional UnsatDetector Constraint Types" do
  describe "type incompatibility constraints" do
    it "detects impossible comparison between integer and string fields with ordering operators" do
      expect do
        build_schema do
          input do
            integer :age
            string :name
          end

          trait :age_greater_than_name, input.age, :>, input.name

          value :result do
            on age_greater_than_name, "Impossible type comparison"
            base "Normal"
          end
        end
      end.to raise_error(Kumi::Errors::TypeError, /argument 2 of `fn\(:>\)` expects float, got input field `name` of declared type string/)
    end

    it "detects impossible comparison between integer and string with ordering" do
      expect do
        build_schema do
          input do
            integer :age
            string :name
          end

          trait :age_less_than_name, input.age, :<, input.name

          value :result do
            on age_less_than_name, "Impossible"
            base "Normal"
          end
        end
      end.to raise_error(Kumi::Errors::TypeError, /argument 2 of `fn\(:<\)` expects float, got input field `name` of declared type string/)
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
            on ages_equal, "Same type comparison"
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
            on impossible_bound, "Impossible bound"
            base "Normal"
          end
        end
      end.to raise_error(Kumi::Errors::SemanticError, /conjunction `impossible_bound` is impossible/)
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
            on impossible_negative, "Impossible negative"
            base "Normal"
          end
        end
      end.to raise_error(Kumi::Errors::SemanticError, /conjunction `impossible_negative` is impossible/)
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
            on valid_bound, "Valid bound"
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
          trait :contradictory, fn(:and, active, inactive) # logically impossible

          value :result do
            on contradictory, "Impossible logic"
            base "Normal"
          end
        end
      end.to raise_error(Kumi::Errors::SemanticError, /conjunction `contradictory` is impossible/)
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
            on is_true,is_false, "Both true and false" # impossible
            base "Normal"
          end
        end
      end.to raise_error(Kumi::Errors::SemanticError, /conjunction `is_true AND is_false` is impossible/)
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
            on both, "Both active and verified"
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
            on is_inactive, "Impossible"
            base "Normal"
          end
        end
      end.to raise_error(Kumi::Errors::SemanticError, /conjunction `is_inactive` is impossible/)
    end

    it "detects contradictory numeric literals" do
      expect do
        build_schema do
          input {}

          value :count, 42
          trait :is_zero, count, :==, 0 # impossible

          value :result do
            on is_zero, "Impossible"
            base "Normal"
          end
        end
      end.to raise_error(Kumi::Errors::SemanticError, /conjunction `is_zero` is impossible/)
    end

    it "allows valid literal comparisons" do
      expect do
        build_schema do
          input {}

          value :status, "active"
          trait :is_active, status, :==, "active" # valid

          value :result do
            on is_active, "Valid"
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
            on impossible_high, "Impossible through chain"
            base "Normal"
          end
        end
      end.to raise_error(Kumi::Errors::SemanticError, /conjunction `impossible_high` is impossible/)
    end
  end

  describe "disjunctive (OR) logic validation" do
    it "correctly handles OR expressions as disjunctive (not conjunctive)" do
      # OR expressions should be disjunctive: (A | B) means "A OR B", not "A AND B"
      # This tests that UnsatDetector properly handles OR logic
      # FIXED: Our OR logic fix resolved the false positive
      expect do
        build_schema do
          input do
            integer :value, domain: 0..10
          end

          # This should be valid: value can be 2 OR 3
          # OR logic should be treated as disjunctive
          # Using fn(:or) syntax since | sugar doesn't work in test method blocks
          trait :valid_or_condition,
                fn(:or, input.value == 2, input.value == 3)

          value :result do
            on valid_or_condition, "Valid"
            base "Invalid"
          end
        end
      end.not_to raise_error
    end

    it "correctly validates complex OR expressions with Game of Life logic" do
      # Complex OR expressions with AND components should work
      # Game of Life rule: (current_alive AND neighbors == 2) OR (neighbors == 3)
      expect do
        build_schema do
          input do
            integer :current_state, domain: 0..1  # 0 = dead, 1 = alive
            integer :neighbors, domain: 0..8      # 0-8 neighbors possible
          end

          # Game of Life survival/birth rule:
          # - Live cell with 2-3 neighbors survives
          # - Dead cell with exactly 3 neighbors becomes alive
          # Using fn(:or) syntax for test method compatibility
          trait :survives_or_born,
                fn(:or,
                   fn(:and, input.current_state == 1, input.neighbors == 2),
                   input.neighbors == 3)

          value :next_state do
            on survives_or_born, 1
            base 0
          end
        end
      end.not_to raise_error
    end

    xit "detects impossible OR expressions where both sides are outside domain" do
      # This does not work in the current implementation
      # This test verifies that impossible OR expressions (where BOTH sides are impossible)
      # are correctly detected and raise an error
      expect do
        build_schema do
          input do
            integer :value, domain: 5..10 # constrained to 5-10
          end

          # Both sides impossible: value can't be 1 OR 2 (both outside domain 5-10)
          # OR is impossible only when BOTH sides are impossible
          trait :impossible_or,
                fn(:or, input.value == 1, input.value == 2)

          value :result do
            on impossible_or, "Should be impossible"
            base "Normal"
          end
        end
      end.to raise_error(Kumi::Errors::SemanticError, /conjunction `impossible_or` is impossible/)
    end

    it "allows OR expressions where one side is possible" do
      # OR should be valid if at least one side is satisfiable
      expect do
        build_schema do
          input do
            integer :value, domain: 5..10 # constrained to 5-10
          end

          # One side possible: value can be 1 (impossible) OR 7 (possible)
          trait :partially_possible_or,
                fn(:or, input.value == 1, input.value == 7)

          value :result do
            on partially_possible_or, "Possible"
            base "Normal"
          end
        end
      end.not_to raise_error
    end

    it "handles nested OR expressions correctly" do
      # Complex nested OR logic should work when properly structured
      expect do
        build_schema do
          input do
            integer :a, domain: 1..10
            integer :b, domain: 1..10
          end

          # Nested OR: (a == 1 OR a == 2) OR (b == 9 OR b == 10)
          trait :complex_or,
                fn(:or,
                   fn(:or, input.a == 1, input.a == 2),
                   fn(:or, input.b == 9, input.b == 10))

          value :result do
            on complex_or, "Complex OR satisfied"
            base "Normal"
          end
        end
      end.not_to raise_error
    end
  end
end
