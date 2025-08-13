# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kumi::Core::Compiler::AccessBuilder do
  include ASTFactory

  context "for object-mode plans" do
    let(:schema) do
      syntax(:root, [
               input_decl(:departments, :array, nil, children: [
                            input_decl(:teams, :array, nil, children: [
                                         input_decl(:team_name, :string)
                                       ], access_mode: :field)
                          ], access_mode: :field)
             ])
    end

    let(:analyzer_result) do
      Kumi::Analyzer.analyze!(schema)
    end

    let(:meta) { analyzer_result.state[:input_metadata] }
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

    it "ravels nested structures" do
      accessors = described_class.build(access_plans)
      accessor = accessors["departments.teams.team_name:ravel"]
      result = accessor.call(data)

      expect(result).to eq(%w[Backend Frontend UX])
    end

    it "ravels array-of-objects without extra nesting" do
      accessors = described_class.build(access_plans)

      ravel = accessors["departments:ravel"]
      # Should produce an array of department objects, not nested-in-an-array
      expect(ravel.call(data)).to eq(data[:departments])
    end
  end

  context "for element-mode (vector) plans" do
    let(:schema) do
      syntax(:root, [
               input_decl(:table, :array, nil, children: [
                            input_decl(:rows, :array, nil, children: [
                                         input_decl(:cell, :array, nil, children: [
                                                      input_decl(:value, :integer)
                                                    ], access_mode: :element)
                                       ], access_mode: :element)
                          ], access_mode: :element)
             ])
    end

    let(:analyzer_result) do
      Kumi::Analyzer.analyze!(schema)
    end

    let(:meta) { analyzer_result.state[:input_metadata] }
    let(:access_plans) { Kumi::Core::Compiler::AccessPlanner.plan(meta) }

    let(:data) do
      {
        table: [
          [[0]], # table -> rows -> (cell is an object)
          [[1, 2], [3]], # table -> rows -> (cell is an array of objects)
          [[4, 5]]
        ]

      }
    end

    it "builds an accessor that correctly enters nested arrays without fetching" do
      accessors = described_class.build(access_plans)

      ops = access_plans["table.rows.cell"].find { |p| p.mode == :materialize }.operations
      expect(ops.map { |o| o[:type] }).to eq(%i[enter_hash enter_array enter_array])

      ops = access_plans["table.rows.cell.value"].find { |p| p.mode == :materialize }.operations
      expect(ops.map { |o| o[:type] }).to eq(%i[enter_hash enter_array enter_array enter_array])

      accessor = accessors["table.rows.cell:materialize"]
      result = accessor.call(data)

      expect(result).to eq(data[:table])

      accessor = accessors["table.rows.cell.value:materialize"]
      result = accessor.call(data)
      expect(result).to eq([[[0]], [[1, 2], [3]], [[4, 5]]])
    end

    it "ravels leaf values to a flat array" do
      accessors = described_class.build(access_plans)
      ravel = accessors["table.rows.cell.value:ravel"]
      expect(ravel.call(data)).to eq([0, 1, 2, 3, 4, 5])
    end

    it "each_indexed yields value with 3-axis indices" do
      accessors = described_class.build(access_plans)
      each = accessors["table.rows.cell.value:each_indexed"]
      expect(each.call(data)).to eq([
                                      [0, [0, 0, 0]],
                                      [1, [1, 0, 0]],
                                      [2, [1, 0, 1]],
                                      [3, [1, 1, 0]],
                                      [4, [2, 0, 0]],
                                      [5, [2, 0, 1]]
                                    ])
    end
  end

  context "when data is missing or nil" do
    let(:schema) do
      syntax(:root, [
               input_decl(:departments, :array, nil, children: [
                            input_decl(:teams, :array, nil, children: [
                                         input_decl(:team_name, :string)
                                       ], access_mode: :field)
                          ], access_mode: :field)
             ])
    end

    let(:analyzer_result) do
      Kumi::Analyzer.analyze!(schema)
    end

    let(:input_metadata) { analyzer_result.state[:input_metadata] }
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

    xit "raises a descriptive error when encountering nil instead of an object" do
      # This can easily be done, just make a helper on Accessors::Base
      # And on Accessors, e.g. ::MaterializeAccessor, keep track of the last key
      # and use it in the error message (might be on a previus op)
      object_schema = syntax(:root, [
                               input_decl(:user, :array, nil, children: [
                                            input_decl(:profile, :array, nil, children: [
                                                         input_decl(:name, :string)
                                                       ], access_mode: :field)
                                          ], access_mode: :field)
                             ])

      object_analyzer_result = Kumi::Analyzer.analyze!(object_schema)
      input_metadata_for_object = object_analyzer_result.state[:input_metadata]
      access_plans_for_object = Kumi::Core::Compiler::AccessPlanner.plan(input_metadata_for_object, defaults: { on_missing: :error })

      data_with_nil_object = {
        user: nil
      }

      accessors = described_class.build(access_plans_for_object)
      accessor = accessors["user.profile.name:materialize"]

      expect { accessor.call(data_with_nil_object) }.to raise_error(
        KeyError,
        /Missing key 'user' at 'user.profile.name' \(object\)/
      )
    end
  end
end
