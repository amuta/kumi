# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Formal Unsat Detection" do
  describe "function constraint semantics metadata" do
    it "loads constraint_semantics from YAML for core.add" do
      registry = Kumi::Core::Functions::Loader.load_minimal_functions
      add_spec = registry["core.add"]

      expect(add_spec.constraint_semantics).not_to be_nil
      expect(add_spec.constraint_semantics[:domain_effect]).to eq(:EXTEND)
      expect(add_spec.constraint_semantics[:pure_combiner]).to be true
      expect(add_spec.constraint_semantics[:commutativity]).to be true
    end

    it "loads constraint_semantics for core.mul" do
      registry = Kumi::Core::Functions::Loader.load_minimal_functions
      mul_spec = registry["core.mul"]

      expect(mul_spec.constraint_semantics).not_to be_nil
      expect(mul_spec.constraint_semantics[:domain_effect]).to eq(:SCALE)
    end

    it "loads NONE domain_effect for spatial operations like shift" do
      registry = Kumi::Core::Functions::Loader.load_minimal_functions
      shift_spec = registry["shift"]

      if shift_spec.constraint_semantics
        expect(shift_spec.constraint_semantics[:domain_effect]).to eq(:NONE)
      end
    end
  end

  describe "obvious literal contradictions" do
    it "detects contradicting equality constraints on same variable" do
      expect do
        build_schema do
          input do
            integer :x
          end

          value :x_value, 100

          # Trait with contradicting equality
          trait :impossible, fn(:and, x_value == 100, x_value == 50)

          value :result do
            on impossible, "Impossible"
            base "Normal"
          end
        end
      end.to raise_error(Kumi::Core::Errors::SemanticError, /impossible/)
    end

    it "detects domain violations for input fields" do
      expect do
        build_schema do
          input do
            integer :age, domain: 0..150
          end

          # Direct constraint that violates domain
          trait :impossible_age, input.age, :==, 200

          value :result do
            on impossible_age, "Impossible"
            base "Normal"
          end
        end
      end.to raise_error(Kumi::Core::Errors::SemanticError, /impossible/)
    end

    it "allows valid constraints" do
      expect do
        build_schema do
          input do
            integer :age, domain: 0..150
          end

          trait :is_adult, input.age, :>=, 18

          value :result do
            on is_adult, "Adult"
            base "Minor"
          end
        end
      end.not_to raise_error
    end
  end
end
