# frozen_string_literal: true

require "spec_helper"

RSpec.describe "UNSAT Detection with Constraint Propagation" do
  describe "detecting impossibility through constraint chains" do
    # NOTE: These tests are ASPIRATIONAL - they document what Phase 2 integration
    # (SNAST Integration) will enable. Currently, constraint propagation is
    # implemented but NOT integrated into the analyzer pipeline.
    #
    # Current Phase 1 Status:
    #   ✅ FormalConstraintPropagator implemented and tested
    #   ✅ Constraint semantics in YAML metadata
    #   ⏳ Integration into analyzer (Phase 2)
    #
    # When Phase 2 is complete, UnsatDetector will use propagated constraints
    # to detect derived impossibilities. These tests will pass at that time.

    pending "detects impossible constraint derived through arithmetic propagation" do
      # This test shows how UnsatDetector COULD use constraint propagation
      # in future phases to detect impossibilities that span multiple operations.
      #
      # Current behavior: Detects direct contradictions (phase 0)
      # Future behavior: Would also detect derived impossibilities through propagation
      expect do
        build_schema do
          input do
            integer :x, domain: 0..10
          end

          value :doubled, fn(:mul, input.x, 2)

          # This is directly unsatisfiable since:
          # x ∈ [0, 10] => doubled ∈ [0, 20]
          # But we explicitly constrain doubled == 50, which violates the bound
          trait :impossible_doubled, doubled == 50

          value :result do
            on impossible_doubled, "Impossible"
            base "Normal"
          end
        end
      end.to raise_error(Kumi::Core::Errors::SemanticError)
    end

    pending "detects impossible reverse constraint derived through arithmetic" do
      # If output is constrained to a value, reverse propagation derives input constraint
      # Then we check if that derived constraint violates input domain
      expect do
        build_schema do
          input do
            integer :x, domain: 0..10
          end

          value :result, fn(:add, input.x, 100)

          # result == 50 means x == -50
          # But x domain is [0, 10], so x cannot be -50
          trait :impossible_result, result == 50

          value :output do
            on impossible_result, "Impossible"
            base "Normal"
          end
        end
      end.to raise_error(Kumi::Core::Errors::SemanticError)
    end

    it "allows valid chained constraints within bounds" do
      # This should NOT raise - the constraint is feasible
      expect do
        build_schema do
          input do
            integer :x, domain: 0..10
          end

          value :doubled, fn(:mul, input.x, 2)

          # doubled in [0, 20], and we constrain doubled <= 20, which is always true
          trait :valid_doubled, doubled <= 20

          value :result do
            on valid_doubled, "Valid"
            base "Invalid"
          end
        end
      end.not_to raise_error
    end

    pending "detects multi-level impossible constraint" do
      # Chain: x -> y = x + 5 -> z = y * 2
      # x ∈ [0, 10] => y ∈ [5, 15] => z ∈ [10, 30]
      # Constraint z == 100 is impossible
      expect do
        build_schema do
          input do
            integer :x, domain: 0..10
          end

          value :y, fn(:add, input.x, 5)
          value :z, fn(:mul, y, 2)

          trait :impossible_z, z == 100

          value :result do
            on impossible_z, "Impossible"
            base "Normal"
          end
        end
      end.to raise_error(Kumi::Core::Errors::SemanticError)
    end

    it "validates constraint feasibility with multiple operations" do
      # x ∈ [1, 5], y = x * 2, z = y + 10
      # z ∈ [12, 20]
      # Constraint z >= 12 is always satisfiable
      expect do
        build_schema do
          input do
            integer :x, domain: 1..5
          end

          value :y, fn(:mul, input.x, 2)
          value :z, fn(:add, y, 10)

          trait :valid_z, z >= 12

          value :result do
            on valid_z, "Valid"
            base "Invalid"
          end
        end
      end.not_to raise_error
    end
  end

  describe "combining contradicting equality with propagation" do
    pending "detects contradicting constraints at different levels" do
      # Direct: x == 5 (from input constraint)
      # Derived: y = x + 10 => y == 15
      # But we also have: trait constraining y == 20
      # This creates a contradiction: y == 15 AND y == 20
      expect do
        build_schema do
          input do
            integer :x
          end

          value :y, fn(:add, input.x, 10)

          trait :x_constraint, input.x == 5
          trait :impossible_y, y == 20
          trait :both_constraints, fn(:and, x_constraint, impossible_y)

          value :result do
            on both_constraints, "Impossible"
            base "Normal"
          end
        end
      end.to raise_error(Kumi::Core::Errors::SemanticError)
    end

    it "allows consistent constraints across operations" do
      expect do
        build_schema do
          input do
            integer :x
          end

          value :y, fn(:add, input.x, 10)

          trait :x_constraint, input.x == 5
          trait :consistent_y, y == 15
          trait :both_consistent, fn(:and, x_constraint, consistent_y)

          value :result do
            on both_consistent, "Consistent"
            base "Inconsistent"
          end
        end
      end.not_to raise_error
    end
  end

  describe "domain propagation detection" do
    pending "catches domain violation in intermediate computation" do
      # Even if input domain is [0, 10], multiplication by 20
      # creates output in [0, 200]
      # Constraint that intermediate is < 0 is impossible
      expect do
        build_schema do
          input do
            integer :x, domain: 0..10
          end

          value :large, fn(:mul, input.x, 20)

          trait :impossible_large, large < 0

          value :result do
            on impossible_large, "Impossible"
            base "Normal"
          end
        end
      end.to raise_error(Kumi::Core::Errors::SemanticError)
    end

    it "allows constraints within expanded domain" do
      expect do
        build_schema do
          input do
            integer :x, domain: 0..10
          end

          value :large, fn(:mul, input.x, 20)

          trait :valid_large, large <= 200

          value :result do
            on valid_large, "Valid"
            base "Invalid"
          end
        end
      end.not_to raise_error
    end
  end
end
