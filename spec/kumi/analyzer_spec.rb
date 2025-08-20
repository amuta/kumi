# frozen_string_literal: true

RSpec.describe Kumi::Analyzer do
  include ASTFactory

  before do
    allow(Kumi::Registry).to receive_messages(confirm_support!: true, signature: { arity: 1 })
  end

  # Contract 1 – happy path on a complex acyclic schema
  context "with a complex, valid schema" do
    subject(:result) { described_class.analyze!(schema) }

    let(:schema) do
      a    = attr(:a) # literal leaf
      b    = attr(:b, ref(:a)) # depends on a
      c    = attr(:c, call(:mul, ref(:a), ref(:b))) # depends on a
      d    = attr(:d, call(:add, lit(3), lit(2))) # independent
      high = trait(:high, call(:gt, ref(:c), lit(10))) # depends on c

      syntax(:root, [], [a, b, c, d], [high], loc: loc)
    end

    it "returns an immutable Result" do
      expect(result).to be_a(Kumi::Analyzer::Result)
      expect(result.dependency_graph.frozen?).to be true
      expect(result.leaf_map.frozen?).to         be true
      expect(result.topo_order.frozen?).to       be true
    end

    it "captures every dependency edge" do
      graph = result.dependency_graph

      # Extract just the 'to' field from edges for simpler testing
      simplified_graph = graph.transform_values { |edges| edges.map(&:to) }

      expect(simplified_graph).to eq(
        b: [:a],
        c: %i[a b],
        high: [:c]
      )

      # Verify edge metadata is present
      expect(graph[:b].first.type).to eq(:ref)
      expect(graph[:b].first.via).to eq(nil)
      expect(graph[:c].first.via).to eq(:mul)
      expect(graph[:high].first.via).to eq(:gt)
    end

    it "collects all terminal leaves" do
      expect(result.leaf_map[:a].map(&:value).first).to eq 1
      expect(result.leaf_map[:d].map(&:value).first).to eq 3
      expect(result.leaf_map[:high].map(&:value).first).to eq 10

      expect(result.leaf_map.size).to eq 3
    end

    it "returns a topological order honouring dependencies" do
      o = result.topo_order
      expect(o.index(:a)).to    be < o.index(:b)
      expect(o.index(:a)).to    be < o.index(:c)
      expect(o.index(:c)).to    be < o.index(:high)
    end
  end

  # Contract 2 – aggregated semantic diagnostics
  context "when schema contains multiple semantic errors" do
    let(:schema) do
      dup1   = attr(:dup)
      dup2   = attr(:dup, lit(2))                      # duplicate
      undef_ = trait(:undef, call(:eq, ref(:missing))) # undefined ref
      bad    = trait(:flag, lit(true))                 # not a CallExpression
      arity  = trait(:arity, call(:noop))              # arity mismatch

      syntax(:root, [], [dup1, dup2], [undef_, bad, arity], loc: loc)
    end

    before { allow(Kumi::Registry).to receive(:signature).and_return({ arity: 2 }) }

    it "raises once, containing first problem" do
      expect do
        described_class.analyze!(schema)
      end.to raise_error(Kumi::Core::Errors::SemanticError) { |e|
        msg = e.message
        expect(msg).to match(/duplicated definition `dup`/)
      }
    end
  end

  # Contract 3 – cycle detection
  context "when dependency graph has a cycle" do
    let(:schema) do
      a = attr(:a, ref(:b))
      b = attr(:b, ref(:a))
      syntax(:root, [], [a, b], [], loc: loc)
    end

    it "fails with a cycle diagnostic" do
      expect do
        described_class.analyze!(schema)
      end.to raise_error(Kumi::Core::Errors::SemanticError, /cycle detected: a → b → a/)
    end
  end

  # Convenience – caller supplies a partial pass list
  context "with a custom pass list containing only NameIndexer" do
    let(:schema) { syntax(:root, [], [attr(:foo)], [], loc: loc) }
    let(:passes) { [Kumi::Core::Analyzer::Passes::NameIndexer] }

    it "runs without error but returns nils for data not produced" do
      res = described_class.analyze!(schema, passes: passes)
      expect(res.dependency_graph).to be_nil
      expect(res.leaf_map).to         be_nil
      expect(res.topo_order).to       be_nil
    end
  end
end
