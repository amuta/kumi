# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kumi::Core::Compiler::AccessPlanner do
  include ASTFactory

  context "array terminals: modes and terminal :enter_array behavior" do
    let(:schema) do
      # items is an array (object access); items.price is a scalar leaf
      syntax(:root, [
               input_decl(:items, :array, nil, access_mode: :field, children: [
                            input_decl(:price, :float)
                          ])
             ])
    end

    let(:meta)  { Kumi::Analyzer.analyze!(schema).state[:input_metadata] }
    let(:plans) { described_class.plan(meta) }

    it "emits no :read plan for array paths" do
      modes = plans.fetch("items").map(&:mode)
      expect(modes).to match_array(%i[each_indexed materialize ravel])
    end

    it "does not append terminal :enter_array for :materialize on array terminals" do
      ops = plans["items"].find { |p| p.mode == :materialize }.operations
      expect(ops.map { |o| o[:type] }).to eq(%i[enter_hash]) # just fetch the array field, don't iterate
    end

    it "appends terminal :enter_array for :ravel on array terminals" do
      ops = plans["items"].find { |p| p.mode == :ravel }.operations
      expect(ops.map { |o| o[:type] }).to eq(%i[enter_hash enter_array])
    end

    it "appends terminal :enter_array for :each_indexed on array terminals" do
      ops = plans["items"].find { |p| p.mode == :each_indexed }.operations
      expect(ops.map { |o| o[:type] }).to eq(%i[enter_hash enter_array])
    end
  end

  context "object-mode nested path vs element-mode nested path" do
    context "object-mode (field edges)" do
      let(:schema) do
        # departments → array of objects → teams (array) → team_name (scalar)
        syntax(:root, [
                 input_decl(:departments, :array, nil, access_mode: :field, children: [
                              input_decl(:teams, :array, nil, access_mode: :field, children: [
                                           input_decl(:team_name, :string)
                                         ])
                            ])
               ])
      end

      let(:meta)  { Kumi::Analyzer.analyze!(schema).state[:input_metadata] }
      let(:plans) { described_class.plan(meta) }

      it "does not add a phantom trailing :enter_array for scalar leaf (:ravel mode)" do
        ops = plans["departments.teams.team_name"].find { |p| p.mode == :ravel }.operations
        # Walk:
        #   root/object → enter_hash("departments")
        #   parent=array → enter_array, then enter_hash("teams")  (field edge)
        #   parent=array → enter_array, then enter_hash("team_name")  (scalar leaf, no trailing array step)
        expect(ops.map { |o| o[:type] }).to eq(
          %i[enter_hash enter_array enter_hash enter_array enter_hash]
        )
      end

      it "materialize preserves structure without entering leaf elements" do
        ops = plans["departments.teams.team_name"].find { |p| p.mode == :materialize }.operations
        expect(ops.map { |o| o[:type] }).to eq(
          %i[enter_hash enter_array enter_hash enter_array enter_hash]
        )
      end
    end

    context "element-mode (alias edges)" do
      let(:schema) do
        # data_cube is an array-of-arrays via element access:
        # data_cube.layer (array alias) → .row (array alias) → .value (scalar via element alias)
        syntax(:root, [
                 input_decl(:data_cube, :array, nil, access_mode: :element, children: [
                              input_decl(:layer, :array, nil, access_mode: :element, children: [
                                           input_decl(:row, :array, nil, access_mode: :element, children: [
                                                        input_decl(:value, :float, nil, access_mode: :element)
                                                      ])
                                         ])
                            ])
               ])
      end

      let(:meta)  { Kumi::Analyzer.analyze!(schema).state[:input_metadata] }
      let(:plans) { described_class.plan(meta) }

      it "adds an array step for every element alias, including the terminal (:ravel mode)" do
        ops = plans["data_cube.layer.row.value"].find { |p| p.mode == :ravel }.operations
        # Walk:
        #   root/object → enter_hash("data_cube")
        #   layer via element alias    → enter_array
        #   row via element alias      → enter_array
        #   value via element alias    → enter_array   (yes, even though the leaf is scalar)
        expect(ops.map { |o| o[:type] }).to eq(
          %i[enter_hash enter_array enter_array enter_array]
        )
      end

      it "materialize still follows all alias edges but does not iterate the terminal elements" do
        ops = plans["data_cube.layer.row.value"].find { |p| p.mode == :materialize }.operations
        # For element mode, your planner emits array steps per alias during traversal,
        # but does *not* add an extra terminal array step just for :materialize.
        expect(ops.map { |o| o[:type] }).to eq(
          %i[enter_hash enter_array enter_array enter_array]
        )
      end
    end
  end
end
