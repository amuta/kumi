# frozen_string_literal: true

RSpec.describe Kumi::Core::Compiler::AccessBuilder do
  context "for object-mode plans" do
    let(:meta) do
      {
        departments: {
          type: :array,
          children: {
            teams: {
              type: :array,
              children: {
                team_name: { type: :string }
              }
            }
          }
        }
      }
    end

    let(:access_plans) { Kumi::Core::Compiler::AccessPlanner.plan(meta) }

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

      accessor = accessors["departments.teams.team_name:materialize"]
      result = accessor.call(data)

      expect(result).to eq([%w[Backend Frontend], ["UX"]])
    end
  end

  context "for element-mode (vector) plans" do
    let(:meta) do
      {
        table: {
          type: :array,
          children: {
            rows: {
              access_mode: :element,
              type: :array,
              children: {
                cell: {
                  type: :array,
                  children: {
                    value: { type: :integer }
                  }
                }
              }
            }
          }
        }
      }
    end
    let(:access_plans) { Kumi::Core::Compiler::AccessPlanner.plan(meta) }

    let(:data) do
      {
        table: [
          [{ value: 0 }],
          [{ value: 1 }, { value: 2 }, { value: 3 }],
          [{ value: 4 }, { value: 5 }]
        ]
      }
    end

    it "builds an accessor that correctly enters nested arrays without fetching" do
      accessors = described_class.build(access_plans)

      ops = access_plans["table.rows.cell"].first[:operations]
      expect(ops.map { |o| o[:type] }).to eq(%i[enter_hash enter_array enter_array])

      ops = access_plans["table.rows.cell.value"].first[:operations]
      expect(ops.map { |o| o[:type] }).to eq(%i[enter_hash enter_array enter_array enter_hash])
      expect(ops.last[:key]).to eq("value")

      accessor = accessors["table.rows.cell:materialize"]
      result = accessor.call(data)

      expect(result).to eq([[{ value: 0 }], [{ value: 1 }, { value: 2 }, { value: 3 }], [{ value: 4 }, { value: 5 }]])

      accessor = accessors["table.rows.cell.value:materialize"]
      result = accessor.call(data)
      expect(result).to eq([[0], [1, 2, 3], [4, 5]])
    end
  end

  context "when data is missing or nil" do
    let(:input_metadata) do
      {
        departments: {
          type: :array,
          children: {
            teams: {
              type: :array,
              children: {
                team_name: { type: :string }
              }
            }
          }
        }
      }
    end

    let(:access_plans) do
      Kumi::Core::Compiler::AccessPlanner.plan(input_metadata, defaults: { on_missing: :error })
    end

    let(:incomplete_data) do
      {
        departments: [
          { name: "Eng", teams: [{ team_name: "Backend" }] },
          { name: "Design" } # This department is missing the 'teams' key
        ]
      }
    end

    it "raises a descriptive error when encountering nil instead of an array" do
      accessors = described_class.build(access_plans)
      expect(accessors).to have_key("departments.teams.team_name:materialize")
      accessor = accessors["departments.teams.team_name:materialize"]

      expect { accessor.call(incomplete_data) }.to raise_error(
        KeyError, /Missing key 'teams' at 'departments.teams.team_name' \(materialize\)/
      )
    end

    it "raises a descriptive error when encountering nil instead of an object" do
      input_metadata_for_object = {
        user: {
          type: :hash,
          children: {
            profile: {
              type: :hash,
              children: {
                name: { type: :string }
              }
            }
          }
        }
      }

      access_plans_for_object = Kumi::Core::Compiler::AccessPlanner.plan(input_metadata_for_object, defaults: { on_missing: :error })

      data_with_nil_object = {
        user: nil
      }

      accessors = described_class.build(access_plans_for_object)
      accessor = accessors["user.profile.name:object"]

      expect { accessor.call(data_with_nil_object) }.to raise_error(
        KeyError,
        /Missing key 'user' at 'user.profile.name' \(object\)/
      )
    end
  end
end
