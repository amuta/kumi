# frozen_string_literal: true

RSpec.describe Kumi::Core::Compiler::AccessPlanner do
  let(:simple_metadata) do
    {
      name: { type: :string },
      age: { type: :integer }
    }
  end

  let(:nested_metadata) do
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
              team_name: { type: :string },
              members: {
                type: :array,
                access_mode: :element,
                children: {
                  first_name: { type: :string },
                  last_name: { type: :string }
                }
              }
            }
          }
        }
      }
    }
  end

  describe ".plan" do
    context "with simple scalar fields" do
      it "returns a Plans struct with object-mode plans" do
        plans = described_class.plan(simple_metadata)

        expect(plans).to be_a(Kumi::Core::Analyzer::AccessPlans::Plans)
        expect(plans.paths).to contain_exactly("name", "age")
        
        name_plan = plans["name"].first
        expect(name_plan).to be_a(Kumi::Core::Analyzer::AccessPlans::Plan)
        expect(name_plan.path).to eq("name")
        expect(name_plan.mode).to eq(:object)
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
      it "returns Plans struct with multiple access modes for array paths" do
        plans = described_class.plan(nested_metadata)

        expect(plans).to be_a(Kumi::Core::Analyzer::AccessPlans::Plans)
        expect(plans.paths).to contain_exactly(
          "departments",
          "departments.name", 
          "departments.teams",
          "departments.teams.team_name",
          "departments.teams.members",
          "departments.teams.members.first_name",
          "departments.teams.members.last_name"
        )

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
        expect(deep_plan.containers).to eq([:departments, :teams])
        expect(deep_plan.scope).to eq([:departments, :teams])
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
        member_plans = plans["departments.teams.members"]

        expect(member_plans.length).to eq(3)
        member_plan = member_plans.find { |p| p.mode == :materialize }

        expect(member_plan.containers).to eq([:departments, :teams, :members])
        expect(member_plan.depth).to eq(3)

        expected_operations = [
          { type: :enter_hash, key: "departments", on_missing: :error, key_policy: :indifferent },
          { type: :enter_array, on_missing: :error },
          { type: :enter_hash, key: "teams", on_missing: :error, key_policy: :indifferent },
          { type: :enter_array, on_missing: :error },
          { type: :enter_array, on_missing: :error }
        ]

        expect(member_plan.operations).to eq(expected_operations)
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

      expect(plans).to be_a(Kumi::Core::Analyzer::AccessPlans::Plans)
      expect(plans.paths).to contain_exactly("departments.teams.team_name")
      
      team_name_plans = plans["departments.teams.team_name"]
      expect(team_name_plans.length).to eq(3)
      expect(team_name_plans.map(&:mode)).to contain_exactly(:each_indexed, :ravel, :materialize)
    end

    it "respects explicit mode option" do
      plans = described_class.plan_for(nested_metadata, "departments.teams.team_name", mode: :ravel)

      team_name_plans = plans["departments.teams.team_name"]
      expect(team_name_plans.length).to eq(1)
      expect(team_name_plans.first.mode).to eq(:ravel)
    end

    it "raises error for unknown path" do
      expect {
        described_class.plan_for(simple_metadata, "unknown.path")
      }.to raise_error(ArgumentError, /Unknown path: unknown.path/)
    end
  end

  describe "Plans struct interface" do
    let(:plans) { described_class.plan(nested_metadata) }

    it "provides array access by path" do
      dept_plans = plans["departments"]
      expect(dept_plans).to be_an(Array)
      expect(dept_plans.length).to eq(3)
    end

    it "returns empty array for non-existent paths" do
      expect(plans["nonexistent"]).to eq([])
    end

    it "provides modes_for helper" do
      modes = plans.modes_for("departments")
      expect(modes).to contain_exactly(:each_indexed, :ravel, :materialize)
    end

    it "provides find helper" do
      plan = plans.find("departments", :ravel)
      expect(plan).to be_a(Kumi::Core::Analyzer::AccessPlans::Plan)
      expect(plan.mode).to eq(:ravel)
    end

    it "provides to_h compatibility shim" do
      hash = plans.to_h
      expect(hash).to be_a(Hash)
      expect(hash.keys).to eq(plans.paths)
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
end
