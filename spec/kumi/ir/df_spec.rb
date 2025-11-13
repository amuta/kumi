# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kumi::IR::DF::Graph do
  describe ".from_snast" do
    it "wraps a SNAST module produced by the factory" do
      snast = build_snast_module(:manager_count, axes: %i[departments], dtype: :integer) do
        salaries = ir_types.array(ir_types.scalar(:integer))
        snast_factory.input_ref(
          path: %i[departments employees salary],
          axes: %i[departments employees],
          dtype: salaries
        )
      end

      graph, fn = df_graph_with_function(snast, name: :manager_count)
      expect(graph).to be_a(described_class)
      expect(graph.name).to eq(:anonymous)

      builder = df_builder(graph:, function: fn)
      axes = snast.decls[:manager_count].meta[:stamp][:axes]
      builder.map(result: :t1, fn: :identity, args: [], axes:, dtype: ir_types.scalar(:integer))

      instr = fn.entry_block.instructions.last
      expect(instr.opcode).to eq(:map)
      expect(instr.axes).to eq(%i[departments])
      expect(instr.attributes[:fn]).to eq(:identity)
    end
  end
end
