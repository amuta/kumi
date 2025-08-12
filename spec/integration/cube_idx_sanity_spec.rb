# frozen_string_literal: true

require "spec_helper"

RSpec.describe "3D cube idx sanity" do
  module CubeSchema
    extend Kumi::Schema
    schema do
      input do
        array :cube do
          element :array, :layer do
            element :array, :matrix do
              element :array, :row do
                element :integer, :cell
              end
            end
          end
        end
      end
      # now expect first yield: [1, [0,0,0,0]]

      value :cube,    input.cube
      value :layer,   input.cube.layer
      value :matrix,  input.cube.layer.matrix
      value :rows,    input.cube.layer.matrix.row
      value :cell, input.cube.layer.matrix.row.cell
    end
  end

  let(:syntax_tree)    { CubeSchema.__syntax_tree__ }
  let(:analysis_state) { Kumi::Analyzer.analyze!(syntax_tree).state }
  let(:plans)          { analysis_state[:access_plans] }
  let(:program)        { Kumi::Runtime::Program.from_analysis(analysis_state) }

  let(:cube_data) do
    { "cube" => [
      [[[1, 2], [3, 4]], [[5, 6, 7]]],
      [[[8, 9], [10, 11], [12, 13]]]
    ] }
  end

  def op_types(path)
    plans.fetch(path).find { |p| p.mode == :each_indexed }.operations.map { |o| o[:type] }
  end
  it "planner emits array hops for every array segment" do
    expect(op_types("cube")).to eq(%i[enter_hash enter_array])
    expect(op_types("cube.layer")).to eq(%i[enter_hash enter_array enter_array])
    expect(op_types("cube.layer.matrix")).to eq(%i[enter_hash enter_array enter_array enter_array])
    expect(op_types("cube.layer.matrix.row")).to eq(%i[enter_hash enter_array enter_array enter_array enter_array])
    expect(op_types("cube.layer.matrix.row.cell")).to eq(%i[enter_hash enter_array enter_array enter_array enter_array])
  end

  it "builder each_indexed yields [val, idx] with rank=4" do
    accessors = Kumi::Core::Compiler::AccessBuilder.build(plans)
    each = accessors.fetch("cube.layer.matrix.row.cell:each_indexed")
    out = each.call(cube_data)
    expect(out.first).to eq([1, [0, 0, 0, 0]])
    expect(out.all? { |v, idx| idx.length == 4 }).to be true
  end

  it "VM produces scalars; IR still tracks indices" do
    ir = analysis_state[:ir_module]

    %i[cube layer matrix cell].each_with_index do |name, i|
      d = ir.decls.find { |x| x.name == name }
      load = d.ops.find { |o| o.tag == :load_input }
      expect(load.attrs[:has_idx]).to be true
      expect(load.attrs[:scope].length).to eq(i + 1) # rank grows 1..4

      lift = d.ops.find { |o| o.tag == :lift }
      expect(lift).not_to be_nil
      expect(lift.attrs[:to_scope].length).to eq(i + 1)

      # final store is scalar
      final_store = d.ops.reverse.find { |o| o.tag == :store }
      expect(final_store.attrs[:name]).to eq(name)
    end

    r = program.read(cube_data) # public API
    expect(r.cube).to   eq(cube_data["cube"])
    expect(r.layer).to  eq(cube_data["cube"])
    expect(r.matrix).to eq(cube_data["cube"])
    expect(r.cell).to   eq(cube_data["cube"])
  end
end
