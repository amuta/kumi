# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kumi::Core::Analyzer::Passes::FormalConstraintPropagator do
  let(:registry) { Kumi::Core::Functions::Loader.load_minimal_functions }
  let(:schema) do
    build_schema do
      input { integer :x }
      value :result, input.x
    end
  end
  let(:state) do
    {
      declarations: {},
      input_metadata: {},
      registry: registry,
      constraints: {}
    }
  end

  describe "forward propagation" do
    it "propagates exact equality through pass-through" do
      # When result is just assigned the input directly
      constraint = { variable: :x, op: :==, value: 10 }
      # For identity (no operation), constraint remains the same
      result = constraint

      expect(result).to eq(variable: :x, op: :==, value: 10)
    end

    it "propagates equality through addition" do
      # x == 5, result = x + 10 => result == 15
      x_constraint = { variable: :x, op: :==, value: 5 }
      propagator = described_class.new(schema, state)

      add_spec = registry["core.add"]
      result = propagator.propagate_forward_through_operation(
        x_constraint,
        add_spec,
        left_operand: :x,
        right_operand: 10,
        result: :sum_result
      )

      expect(result).to eq(variable: :sum_result, op: :==, value: 15)
    end

    it "propagates equality through multiplication" do
      # x == 5, result = x * 3 => result == 15
      x_constraint = { variable: :x, op: :==, value: 5 }
      propagator = described_class.new(schema, state)

      mul_spec = registry["core.mul"]
      result = propagator.propagate_forward_through_operation(
        x_constraint,
        mul_spec,
        left_operand: :x,
        right_operand: 3,
        result: :product
      )

      expect(result).to eq(variable: :product, op: :==, value: 15)
    end

    it "propagates range constraints through addition" do
      # x in [0, 50], result = x + 5 => result in [5, 55]
      x_constraint = { variable: :x, op: :range, min: 0, max: 50 }
      propagator = described_class.new(schema, state)

      add_spec = registry["core.add"]
      result = propagator.propagate_forward_through_operation(
        x_constraint,
        add_spec,
        left_operand: :x,
        right_operand: 5,
        result: :sum_result
      )

      expect(result).to eq(variable: :sum_result, op: :range, min: 5, max: 55)
    end
  end

  describe "reverse propagation" do
    it "derives input equality from output equality through addition" do
      # result == 100, result = x + 10 => x == 90
      result_constraint = { variable: :sum_result, op: :==, value: 100 }
      propagator = described_class.new(schema, state)

      add_spec = registry["core.add"]
      derived = propagator.propagate_reverse_through_operation(
        result_constraint,
        add_spec,
        left_operand: :x,
        right_operand: 10,
        result: :sum_result
      )

      expect(derived).to include(variable: :x, op: :==, value: 90)
    end

    it "derives input equality from output equality through multiplication" do
      # result == 100, result = x * 5 => x == 20
      result_constraint = { variable: :product, op: :==, value: 100 }
      propagator = described_class.new(schema, state)

      mul_spec = registry["core.mul"]
      derived = propagator.propagate_reverse_through_operation(
        result_constraint,
        mul_spec,
        left_operand: :x,
        right_operand: 5,
        result: :product
      )

      expect(derived).to include(variable: :x, op: :==, value: 20)
    end

    it "derives input range from output range through addition" do
      # result in [100, 110], result = x + 10 => x in [90, 100]
      result_constraint = { variable: :sum_result, op: :range, min: 100, max: 110 }
      propagator = described_class.new(schema, state)

      add_spec = registry["core.add"]
      derived = propagator.propagate_reverse_through_operation(
        result_constraint,
        add_spec,
        left_operand: :x,
        right_operand: 10,
        result: :sum_result
      )

      expect(derived).to include(variable: :x, op: :range, min: 90, max: 100)
    end

    it "handles multiplication with range propagation" do
      # result in [0, 100], result = x * 2 => x in [0, 50]
      result_constraint = { variable: :product, op: :range, min: 0, max: 100 }
      propagator = described_class.new(schema, state)

      mul_spec = registry["core.mul"]
      derived = propagator.propagate_reverse_through_operation(
        result_constraint,
        mul_spec,
        left_operand: :x,
        right_operand: 2,
        result: :product
      )

      expect(derived).to include(variable: :x, op: :range, min: 0, max: 50)
    end
  end

  describe "chained propagation" do
    it "chains forward propagation through multiple operations" do
      # x == 10
      # y = x + 5  => y == 15
      # z = y * 2  => z == 30
      propagator = described_class.new(schema, state)

      x_constraint = { variable: :x, op: :==, value: 10 }

      add_spec = registry["core.add"]
      y_constraint = propagator.propagate_forward_through_operation(
        x_constraint,
        add_spec,
        left_operand: :x,
        right_operand: 5,
        result: :y
      )

      expect(y_constraint).to eq(variable: :y, op: :==, value: 15)

      mul_spec = registry["core.mul"]
      z_constraint = propagator.propagate_forward_through_operation(
        y_constraint,
        mul_spec,
        left_operand: :y,
        right_operand: 2,
        result: :z
      )

      expect(z_constraint).to eq(variable: :z, op: :==, value: 30)
    end
  end
end
