# frozen_string_literal: true

require_relative "../../../../lib/kumi/core/compiler/accessor_planner"

RSpec.describe Kumi::Core::Compiler::AccessorPlanner do
  context "for object-mode paths" do
    let(:input_metadata) do
      {
        departments: {
          type: :array,
          access_mode: :object,
          children: {
            name: { type: :string },
            teams: {
              type: :array,
              access_mode: :object,
              children: {
                team_name: { type: :string }
              }
            }
          }
        }
      }
    end

    it "generates a sequence of enter_object and enter_array operations" do
      plans = described_class.plan(input_metadata)
      operations = plans.dig("departments.teams.team_name", :element, :operations)

      expected_operations = [
        { type: :enter_object, key: :departments },
        { type: :enter_array },
        { type: :enter_object, key: :teams },
        { type: :enter_array },
        { type: :enter_object, key: :team_name }
      ]

      expect(operations).to eq(expected_operations)
    end
  end

  context "for element-mode (vector) paths" do
    let(:input_metadata) do
      {
        table: {
          type: :array,
          access_mode: :vector,
          children: {
            rows: {
              type: :array,
              access_mode: :vector,
              children: {
                cell: { type: :integer }
              }
            }
          }
        }
      }
    end

    it "omits enter_object operations after entering a vector array" do
      plans = described_class.plan(input_metadata)
      operations = plans.dig("table.rows.cell", :element, :operations)

      # The key is that :rows and :cell do NOT have an :enter_object operation,
      # as the traversal is implicit in element-mode.
      expected_operations = [
        { type: :enter_object, key: :table },
        { type: :enter_array }, # Enters the table
        { type: :enter_array }  # Enters each row
      ]

      expect(operations).to eq(expected_operations)
    end
  end

  context "for flattened plans" do
    let(:input_metadata) do
      {
        table: {
          type: :array,
          access_mode: :vector,
          children: {
            rows: { type: :array, access_mode: :vector, children: { cell: { type: :integer } } }
          }
        }
      }
    end

    it "adds a :flatten operation at the end of the plan" do
      plans = described_class.plan(input_metadata)
      operations = plans.dig("table.rows.cell", :flattened, :operations)

      expected_base_operations = [
        { type: :enter_object, key: :table },
        { type: :enter_array },
        { type: :enter_array }
      ]

      expect(operations).to start_with(*expected_base_operations)
      expect(operations.last).to eq({ type: :flatten })
    end
  end
end
