# frozen_string_literal: true

RSpec.describe Kumi::Analyzer::Passes::Toposorter do
  def toposort(graph)
    state = { dependency_graph: graph }
    described_class.new(nil, state).run([])
    state[:topo_order]
  end

  describe ".run" do
    context "with simple dependency chain" do
      it "returns parents after dependencies in deterministic order" do
        order = toposort(a: %i[b c], b: %i[c], c: [])
        expect(order.index(:c)).to be < order.index(:b)
        expect(order.index(:b)).to be < order.index(:a)
      end
    end

    context "with disconnected subgraphs" do
      it "includes all nodes" do
        order = toposort(x: [], y: [])
        expect(order).to match_array(%i[x y])
      end
    end
  end
end
