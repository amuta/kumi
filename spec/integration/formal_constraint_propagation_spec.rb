# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Formal Constraint Propagation" do
  describe "constraint propagation metadata structure" do
    it "loads forward propagation rules from YAML for core.add" do
      registry = Kumi::Core::Functions::Loader.load_minimal_functions
      add_spec = registry["core.add"]

      expect(add_spec.constraint_semantics).not_to be_nil
      expect(add_spec.constraint_semantics[:forward_propagation]).not_to be_nil
      expect(add_spec.constraint_semantics[:forward_propagation]).to be_a(Hash)
    end

    it "loads reverse propagation rules from YAML for core.mul" do
      registry = Kumi::Core::Functions::Loader.load_minimal_functions
      mul_spec = registry["core.mul"]

      expect(mul_spec.constraint_semantics).not_to be_nil
      expect(mul_spec.constraint_semantics[:reverse_propagation]).not_to be_nil
      expect(mul_spec.constraint_semantics[:reverse_propagation]).to be_a(Hash)
    end
  end

  describe "forward propagation" do
    it "propagates equality through identity transformations" do
      expect do
        build_schema do
          input do
            integer :x
          end

          value :doubled, fn(:mul, input.x, 2)

          trait :x_constraint, input.x == 10

          value :result do
            on x_constraint, "x is 10"
            base "x is not 10"
          end
        end
      end.not_to raise_error
    end

    it "propagates domain constraints through arithmetic" do
      expect do
        build_schema do
          input do
            integer :x, domain: 0..50
          end

          value :x_plus_5, fn(:add, input.x, 5)

          trait :result_in_valid_range, x_plus_5 <= 55

          value :result do
            on result_in_valid_range, "Valid"
            base "Invalid"
          end
        end
      end.not_to raise_error
    end
  end

  describe "reverse propagation" do
    it "derives input domain from output constraint through addition" do
      expect do
        build_schema do
          input do
            integer :x
          end

          value :x_plus_10, fn(:add, input.x, 10)

          trait :result_constraint, x_plus_10 == 100

          value :result do
            on result_constraint, "Result is 100, so x must be 90"
            base "Result is not 100"
          end
        end
      end.not_to raise_error
    end

    it "derives input domain from output constraint through multiplication" do
      expect do
        build_schema do
          input do
            integer :x, domain: -100..100
          end

          value :x_times_2, fn(:mul, input.x, 2)

          trait :result_range, fn(:and, x_times_2 >= -50, x_times_2 <= 50)

          value :result do
            on result_range, "x must be in [-25, 25]"
            base "x is outside range"
          end
        end
      end.not_to raise_error
    end
  end

  describe "combined propagation" do
    it "chains multiple constraints through propagation" do
      expect do
        build_schema do
          input do
            integer :a, domain: 0..50
            integer :b, domain: 0..50
          end

          value :sum_ab, fn(:add, input.a, input.b)
          value :doubled_sum, fn(:mul, sum_ab, 2)

          trait :result_constraint, doubled_sum <= 150

          value :result do
            on result_constraint, "Valid"
            base "Invalid"
          end
        end
      end.not_to raise_error
    end
  end
end
