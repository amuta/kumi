# frozen_string_literal: true

require_relative "../../../../lib/kumi/core/compiler/accessor_builder"

RSpec.describe Kumi::Core::Compiler::AccessorBuilder do
  context "for object-mode plans" do
    let(:access_plans) do
      {
        "departments.teams.team_name" => {
          element: {
            type: :element,
            path: %i[departments teams team_name],
            operations: [
              { type: :enter_object, key: :departments },
              { type: :enter_array },
              { type: :enter_object, key: :teams },
              { type: :enter_array },
              { type: :enter_object, key: :team_name }
            ]
          }
        }
      }
    end

    let(:data) do
      {
        departments: [
          { name: "Eng", teams: [{ team_name: "Backend" }, { team_name: "Frontend" }] },
          { name: "Design", teams: [{ team_name: "UX" }] }
        ]
      }
    end

    it "builds an accessor that navigates nested objects and arrays" do
      accessors = described_class.build(access_plans)
      accessor = accessors["departments.teams.team_name:element"]
      result = accessor.call(data)

      expect(result).to eq([%w[Backend Frontend], ["UX"]])
    end
  end

  context "for element-mode (vector) plans" do
    let(:access_plans) do
      {
        "table.rows.cell" => {
          element: {
            type: :element,
            path: %i[table rows cell],
            operations: [
              { type: :enter_object, key: :table },
              { type: :enter_array },
              { type: :enter_array }
            ]
          }
        }
      }
    end

    let(:data) do
      {
        table: [
          [0],
          [1, 2, 3],
          [4, 5]
        ]
      }
    end

    it "builds an accessor that correctly enters nested arrays without fetching" do
      accessors = described_class.build(access_plans)
      accessor = accessors["table.rows.cell:element"]
      result = accessor.call(data)

      expect(result).to eq([[0], [1, 2, 3], [4, 5]])
    end
  end

  context "when data is missing or nil" do
    let(:access_plans) do
      {
        "departments.teams.team_name" => {
          element: {
            type: :element,
            path: %i[departments teams team_name],
            operations: [
              { type: :enter_object, key: :departments },
              { type: :enter_array },
              { type: :enter_object, key: :teams },
              { type: :enter_array },
              { type: :enter_object, key: :team_name }
            ]
          }
        }
      }
    end

    let(:incomplete_data) do
      {
        departments: [
          { name: "Eng", teams: [{ team_name: "Backend" }] },
          { name: "Design" } # This department is missing the 'teams' key
        ]
      }
    end

    it "gracefully returns nil instead of raising an error" do
      accessors = described_class.build(access_plans)
      accessor = accessors["departments.teams.team_name:element"]
      result = accessor.call(incomplete_data)

      # The second department's result should be nil because 'teams' was missing.
      expect(result).to eq([["Backend"], nil])
    end
  end
end
