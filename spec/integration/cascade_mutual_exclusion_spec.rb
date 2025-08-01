# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Cascade mutual exclusion detection" do
  context "when cascade conditions are mutually exclusive" do
    it "allows mutual recursion through cascade base cases" do
      module TestMutualRecursionSchema
        extend Kumi::Schema

        schema do
          input do
            integer :n
          end

          trait :n_is_zero, input.n, :==, 0
          trait :n_is_one, input.n, :==, 1

          value :is_even do
            on n_is_zero, true
            on n_is_one, false
            base fn(:not, is_odd)
          end

          value :is_odd do
            on n_is_zero, false
            on n_is_one, true
            base fn(:not, is_even)
          end
        end
      end

      # Should compile without cycle error - no exception means success

      # Should work correctly
      runner = TestMutualRecursionSchema.from(n: 0)
      result = runner.slice(:is_even, :is_odd)
      expect(result[:is_even]).to eq(true)
      expect(result[:is_odd]).to eq(false)

      runner = TestMutualRecursionSchema.from(n: 1)
      result = runner.slice(:is_even, :is_odd)
      expect(result[:is_even]).to eq(false)
      expect(result[:is_odd]).to eq(true)

      # NOTE: Base case (n=2) would cause infinite recursion since neither n==0 nor n==1
      # This is expected - the mutual exclusion feature only ensures safe cycles can be compiled,
      # not that they terminate. Proper termination logic needs to be implemented separately.
    end

    it "detects when ALL cascade conditions are mutually exclusive" do
      module TestAllMutuallyExclusiveSchema
        extend Kumi::Schema

        schema do
          input do
            string :status
          end

          trait :is_active, input.status, :==, "active"
          trait :is_pending, input.status, :==, "pending"
          trait :is_cancelled, input.status, :==, "cancelled"

          value :process_flow do
            on is_active, "continue_processing"
            on is_pending, "wait_for_approval"
            on is_cancelled, "stop_processing"
            base process_flow # Self-reference cycle
          end

          value :reverse_flow do
            on is_active, "reverse_active"
            on is_pending, "reverse_pending"
            base process_flow # Depends on process_flow
          end
        end
      end

      # Should compile - all conditions are mutually exclusive (no exception means success)
    end

    # it "works with identities (value is the same as input)" do
    #   pending "We can't detect the mutual exclusion through identities yet"
    #   # Maybe we should do the mutual exclusion detection within ConstraintRelationshipSolver
    #   # because it already handles node's identity propagation.
    #   module TestMutualRecursionSchema
    #     extend Kumi::Schema

    # TODO: Uncomment and make this work :D
    #     schema do
    #       input do
    #         integer :n
    #       end

    #       trait :n_is_zero, input.n, :==, 0
    #       value :value_input_n, input.n
    #       trait :n_is_one, value_input_n, :==, 1

    #       value :is_even do
    #         on n_is_zero, true
    #         on n_is_one, false
    #         base fn(:not, is_odd)
    #       end

    #       value :is_odd do
    #         on n_is_zero, false
    #         on n_is_one, true
    #         base fn(:not, is_even)
    #       end
    #     end
    #   end

    #   # Should compile - the mutual exclusion only applies to the even/odd conditions,
    #   # not the positive/negative ones (no exception means success)
    # end
  end

  context "when cascade conditions are NOT mutually exclusive" do
    it "still detects unsafe cycles" do
      expect do
        Kumi.schema do
          input do
            integer :n
          end

          trait :n_positive, input.n, :>, 0
          trait :n_even, fn(:modulo, input.n, 2), :==, 0

          value :unsafe_cycle do
            on n_positive, "positive"
            on n_even, "even"
            base fn(:not, unsafe_cycle) # NOT mutually exclusive - both can be true
          end
        end
      end.to raise_error(Kumi::Errors::SemanticError, /cycle detected/)
    end

    it "detects cycles with no cascade conditions" do
      expect do
        Kumi.schema do
          value :always_cycles do
            base fn(:not, always_cycles) # No conditions, always cycles
          end
        end
      end.to raise_error(Kumi::Errors::SemanticError, /cycle detected/)
    end
  end

  context "complex mutual exclusion patterns" do
    it "handles cascades with multiple mutually exclusive condition groups" do
      module TestMultipleGroupsSchema
        extend Kumi::Schema

        schema do
          input do
            integer :x
            integer :y
          end

          # Group 1: x conditions (mutually exclusive)
          trait :x_is_zero, input.x, :==, 0
          trait :x_is_one, input.x, :==, 1

          # Group 2: y conditions (mutually exclusive)
          trait :y_is_zero, input.y, :==, 0
          trait :y_is_one, input.y, :==, 1

          value :x_category do
            on x_is_zero, "x_zero"
            on x_is_one, "x_one"
            base y_category  # Base case depends on y_category
          end

          value :y_category do
            on y_is_zero, "y_zero"
            on y_is_one, "y_one"
            base x_category  # Base case depends on x_category
          end
        end
      end

      # Should compile - the mutual dependency only happens in base cases when no conditions match
      # Both cascades have mutually exclusive conditions within each cascade (no exception means success)

      # Test execution with conditions that match
      runner = TestMultipleGroupsSchema.from(x: 1, y: 0)
      result = runner.slice(:x_category, :y_category)
      expect(result[:x_category]).to eq("x_one")
      expect(result[:y_category]).to eq("y_zero")
    end
  end

  context "partial mutual exclusion" do
    it "requires ALL conditions to be mutually exclusive for safety" do
      expect do
        Kumi.schema do
          input do
            integer :n
          end

          trait :n_is_zero, input.n, :==, 0
          trait :n_is_one, input.n, :==, 1
          trait :n_is_positive, input.n, :>, 0 # NOT exclusive with n_is_one!

          value :partial_exclusive do
            on n_is_zero, true
            on n_is_one, false
            on n_is_positive, true
            base fn(:not, partial_exclusive_2)
          end

          value :partial_exclusive_2 do
            base fn(:not, partial_exclusive)
          end
        end
      end.to raise_error(Kumi::Errors::SemanticError, /cycle detected/)
    end
  end

  describe "metadata availability" do
    it "exposes cascade mutual exclusion information in analyzer result" do
      module TestMetadataSchema
        extend Kumi::Schema

        schema do
          input do
            integer :n
          end

          trait :n_is_zero, input.n, :==, 0
          trait :n_is_one, input.n, :==, 1

          value :is_even do
            on n_is_zero, true
            on n_is_one, false
            base fn(:not, is_odd)
          end

          value :is_odd do
            on n_is_zero, false
            on n_is_one, true
            base fn(:not, is_even)
          end
        end
      end

      # Access the analyzer result through the module instance variables
      analyzer_result = TestMetadataSchema.instance_variable_get(:@__analyzer_result__)
      cascades = analyzer_result.state[:cascades]

      expect(cascades).to include(:is_even, :is_odd)
      expect(cascades[:is_even]).to include(
        condition_traits: %i[n_is_zero n_is_one],
        all_mutually_exclusive: true,
        condition_count: 2
      )
      expect(cascades[:is_odd]).to include(
        condition_traits: %i[n_is_zero n_is_one],
        all_mutually_exclusive: true,
        condition_count: 2
      )
    end
  end
end
