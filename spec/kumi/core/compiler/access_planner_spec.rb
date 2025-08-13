# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kumi::Core::Compiler::AccessPlanner do
  include ASTFactory

  let(:simple_schema) do
    syntax(:root, [
             input_decl(:name, :string),
             input_decl(:age, :integer)
           ])
  end

  let(:simple_analyzer_result) { Kumi::Analyzer.analyze!(simple_schema) }
  let(:simple_metadata) { simple_analyzer_result.state[:input_metadata] }

  let(:nested_schema) do
    syntax(:root, [
             input_decl(:departments, :array, nil, children: [
                          input_decl(:name, :string),
                          input_decl(:teams, :array, nil, children: [
                                       input_decl(:team_name, :string),
                                       input_decl(:scores, :array, nil, children: [
                                                    input_decl(:value, :integer)
                                                  ], access_mode: :field)
                                     ], access_mode: :field)
                        ], access_mode: :field)
           ])
  end

  let(:nested_analyzer_result) { Kumi::Analyzer.analyze!(nested_schema) }
  let(:nested_metadata) { nested_analyzer_result.state[:input_metadata] }

  describe ".plan" do
    context "with simple scalar fields" do
      it "returns a Plans struct with object-mode plans" do
        plans = described_class.plan(simple_metadata)

        expect(plans).to be_a(Hash)
        expect(plans.keys).to contain_exactly("name", "age")

        name_plan = plans["name"].first
        expect(name_plan).to be_a(Kumi::Core::Analyzer::AccessPlan)
        expect(name_plan.path).to eq("name")
        expect(name_plan.mode).to eq(:read)
        expect(name_plan.depth).to eq(0)
        expect(name_plan.scalar?).to be(true)
        expect(name_plan.containers).to eq([])
        expect(name_plan.leaf).to eq(:name)
        expect(name_plan.operations).to eq([
                                             { type: :enter_hash, key: "name", on_missing: :error, key_policy: :indifferent }
                                           ])
      end
    end

    context "with nested array structures" do
      it "returns Hash with multiple access modes for array paths" do
        plans = described_class.plan(nested_metadata)

        expect(plans).to be_a(Hash)
        expect(plans.keys).to contain_exactly("departments",
                                              "departments.name",
                                              "departments.teams",
                                              "departments.teams.team_name",
                                              "departments.teams.scores",
                                              "departments.teams.scores.value")

        dept_plans = plans["departments"]
        expect(dept_plans.length).to eq(3)
        expect(dept_plans.map(&:mode)).to contain_exactly(:each_indexed, :ravel, :materialize)

        team_name_plans = plans["departments.teams.team_name"]
        expect(team_name_plans.length).to eq(3)
        expect(team_name_plans.map(&:mode)).to contain_exactly(:each_indexed, :ravel, :materialize)
      end

      it "creates Plan structs with complete metadata" do
        plans = described_class.plan(nested_metadata)
        deep_plan = plans["departments.teams.team_name"].find { |p| p.mode == :each_indexed }

        expect(deep_plan.path).to eq("departments.teams.team_name")
        expect(deep_plan.containers).to eq(%i[departments teams])
        expect(deep_plan.scope).to eq(%i[departments teams])
        expect(deep_plan.leaf).to eq(:team_name)
        expect(deep_plan.depth).to eq(2)
        expect(deep_plan.ndims).to eq(2)
        expect(deep_plan.mode).to eq(:each_indexed)
        expect(deep_plan.on_missing).to eq(:error)
        expect(deep_plan.key_policy).to eq(:indifferent)
        expect(deep_plan.scalar?).to be(false)
        expect(deep_plan.accessor_key).to eq("departments.teams.team_name:each_indexed")
      end

      it "generates correct operation sequences for nested paths" do
        plans = described_class.plan(nested_metadata)
        deep_plan = plans["departments.teams.team_name"].first

        expected_operations = [
          { type: :enter_hash, key: "departments", on_missing: :error, key_policy: :indifferent },
          { type: :enter_array, on_missing: :error },
          { type: :enter_hash, key: "teams", on_missing: :error, key_policy: :indifferent },
          { type: :enter_array, on_missing: :error },
          { type: :enter_hash, key: "team_name", on_missing: :error, key_policy: :indifferent }
        ]

        expect(deep_plan.operations).to eq(expected_operations)
      end

      it "handles element-mode arrays correctly" do
        plans = described_class.plan(nested_metadata)
        scores_plans = plans["departments.teams.scores"]

        expect(scores_plans.length).to eq(3)
        scores_plan = scores_plans.find { |p| p.mode == :materialize }

        expect(scores_plan.containers).to eq(%i[departments teams scores])
        expect(scores_plan.depth).to eq(3)

        expected_operations = [
          { type: :enter_hash, key: "departments", on_missing: :error, key_policy: :indifferent },
          { type: :enter_array, on_missing: :error },
          { type: :enter_hash, key: "teams", on_missing: :error, key_policy: :indifferent },
          { type: :enter_array, on_missing: :error },
          { type: :enter_hash, key: "scores", on_missing: :error, key_policy: :indifferent }
        ]

        expect(scores_plan.operations).to eq(expected_operations)
      end
    end

    context "with custom options" do
      it "respects custom on_missing and key_policy options" do
        plans = described_class.plan(simple_metadata, on_missing: :skip, key_policy: :string)

        name_plan = plans["name"].first
        expect(name_plan.on_missing).to eq(:skip)
        expect(name_plan.key_policy).to eq(:string)
        expect(name_plan.operations).to eq([
                                             { type: :enter_hash, key: "name", on_missing: :skip, key_policy: :string }
                                           ])
      end
    end
  end

  describe ".plan_for" do
    it "returns Plans struct for specific path" do
      plans = described_class.plan_for(nested_metadata, "departments.teams.team_name")

      expect(plans).to be_a(Hash)
      expect(plans.keys).to contain_exactly("departments.teams.team_name")

      team_name_plans = plans["departments.teams.team_name"]
      expect(team_name_plans).to be_an(Array)
      expect(team_name_plans.length).to eq(3) # each_indexed, r
      expect(team_name_plans.map(&:mode)).to contain_exactly(:each_indexed, :ravel, :materialize)
    end

    it "respects explicit mode option" do
      plans = described_class.plan_for(nested_metadata, "departments.teams.team_name", mode: :ravel)

      team_name_plans = plans["departments.teams.team_name"]
      expect(team_name_plans.length).to eq(1)
      expect(team_name_plans.first.mode).to eq(:ravel)
    end

    it "raises error for unknown path" do
      expect do
        described_class.plan_for(simple_metadata, "unknown.path")
      end.to raise_error(ArgumentError, /Missing required field 'unknown'/)
    end
  end

  describe "Plan struct interface" do
    let(:plans) { described_class.plan(nested_metadata) }
    let(:plan) { plans["departments.teams.team_name"].find { |p| p.mode == :each_indexed } }

    it "provides accessor_key helper" do
      expect(plan.accessor_key).to eq("departments.teams.team_name:each_indexed")
    end

    it "provides ndims alias for depth" do
      expect(plan.ndims).to eq(plan.depth)
      expect(plan.ndims).to eq(2)
    end

    it "provides scalar? helper" do
      simple_plans = described_class.plan(simple_metadata)
      scalar_plan = simple_plans["name"].first
      array_plan = plans["departments"].first

      expect(scalar_plan.scalar?).to be(true)
      expect(array_plan.scalar?).to be(false)
    end

    it "freezes struct instances" do
      expect(plan).to be_frozen
    end
  end

  describe "Declarative Access Scenarios" do
    # Test the internal should_enter_array? and should_enter_hash? logic
    # with clear scenario names to ensure comprehensive coverage

    let(:planner) { described_class.new({}, {}) }

    # Metadata fixtures for different scenarios
    let(:scalar_meta) { { type: :integer } }
    let(:regular_array_meta) { { type: :array, access_mode: :field } }
    let(:element_array_meta) { { type: :array, access_mode: :element } }
    let(:hash_meta) { { type: :hash } }
  end

  describe "3D Element Array Integration" do
    let(:cube_schema) do
      syntax(:root, [
               input_decl(:cube, :array, nil, children: [
                            input_decl(:layer, :array, nil, children: [
                                         input_decl(:matrix, :array, nil, children: [
                                                      input_decl(:cell, :integer)
                                                    ], access_mode: :field)
                                       ], access_mode: :field)
                          ], access_mode: :field)
             ])
    end

    let(:cube_analyzer_result) { Kumi::Analyzer.analyze!(cube_schema) }
    let(:cube_metadata) { cube_analyzer_result.state[:input_metadata] }

    context "when AccessPlanner generates operations for nested element arrays" do
      it "cube path should enter hash only (depth 1)" do
        plans = described_class.plan(cube_metadata)
        cube_plan = plans["cube"].find { |p| p.mode == :materialize }

        expect(cube_plan.operations).to eq([
                                             { type: :enter_hash, key: "cube", on_missing: :error, key_policy: :indifferent }
                                           ])
        expect(cube_plan.depth).to eq(1)
      end

      it "cube.layer path should generate operations for layer traversal" do
        plans = described_class.plan(cube_metadata)
        layer_plan = plans["cube.layer"].find { |p| p.mode == :each_indexed }

        expect(layer_plan.operations).to eq([
                                              { type: :enter_hash, key: "cube", on_missing: :error, key_policy: :indifferent },
                                              { type: :enter_array, on_missing: :error },
                                              { type: :enter_hash, key: "layer", on_missing: :error, key_policy: :indifferent },
                                              { type: :enter_array, on_missing: :error }
                                            ])
        expect(layer_plan.depth).to eq(2)
      end

      it "cube.layer.matrix path should generate operations for matrix traversal within layers" do
        plans = described_class.plan(cube_metadata)
        matrix_plan = plans["cube.layer.matrix"].find { |p| p.mode == :materialize }

        expect(matrix_plan.operations).to eq([
                                               { type: :enter_hash, key: "cube", on_missing: :error, key_policy: :indifferent },
                                               { type: :enter_array, on_missing: :error },
                                               { type: :enter_hash, key: "layer", on_missing: :error, key_policy: :indifferent },
                                               { type: :enter_array, on_missing: :error },
                                               { type: :enter_hash, key: "matrix", on_missing: :error, key_policy: :indifferent }
                                             ])
        expect(matrix_plan.depth).to eq(3)
      end

      it "cube.layer.matrix.cell path should generate full traversal to leaf cells" do
        plans = described_class.plan(cube_metadata)
        cell_plan = plans["cube.layer.matrix.cell"].first

        expect(cell_plan.operations).to eq([
                                             { type: :enter_hash, key: "cube", on_missing: :error, key_policy: :indifferent },
                                             { type: :enter_array, on_missing: :error },
                                             { type: :enter_hash, key: "layer", on_missing: :error, key_policy: :indifferent },
                                             { type: :enter_array, on_missing: :error },
                                             { type: :enter_hash, key: "matrix", on_missing: :error, key_policy: :indifferent },
                                             { type: :enter_array, on_missing: :error },
                                             { type: :enter_hash, key: "cell", on_missing: :error, key_policy: :indifferent }
                                           ])
        expect(cell_plan.depth).to eq(3)
      end
    end
  end
end
