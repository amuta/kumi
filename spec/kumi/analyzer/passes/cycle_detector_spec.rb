# frozen_string_literal: true

RSpec.describe Kumi::Analyzer::Passes::CycleDetector do
  include ASTFactory

  def detect(graph_spec)
    graph = dependency_graph(**graph_spec)
    state = { dependency_graph: graph }
    errors = []
    described_class.new(nil, state).run(errors)
    errors.map(&:last)                 # return just the messages
  end

  describe ".run" do
    context "with acyclic graph" do
      it "records no errors" do
        expect(detect(a: [:b], b: [])).to be_empty
      end
    end

    context "with self-loop" do
      it "detects a node that references itself" do
        msgs = detect(a: [:a])
        expect(msgs.first).to match(/cycle detected: a → a/)
      end
    end

    context "with two-node cycle" do
      it "detects a ↔ b" do
        msgs = detect(a: [:b], b: [:a])
        expect(msgs.first).to match(/cycle detected: a → b → a/)
      end
    end

    context "with three-node ring" do
      it "detects a → b → c → a" do
        msgs = detect(a: [:b], b: [:c], c: [:a])
        expect(msgs.first).to match(/cycle detected: a → b → c → a/)
      end
    end

    context "with multiple disconnected cycles" do
      it "reports at least one message per cycle" do
        msgs = detect(
          a: [:b], b: [:a],          # cycle 1
          x: [:y], y: [:x],          # cycle 2
          k: []                      # acyclic node
        )

        expect(msgs.size).to be >= 2
        expect(msgs.any? { |m| m.match?(/a → b → a/) }).to be true
        expect(msgs.any? { |m| m.match?(/x → y → x/) }).to be true
      end
    end

    context "with cycle plus acyclic subgraph" do
      it "ignores acyclic parts and flags the cycle" do
        msgs = detect(
          a: [:b], b: [:a], # cycle
          c: [:d], d: []    # acyclic chain
        )

        expect(msgs.first).to match(/cycle detected: a → b → a/)
        expect(msgs.size).to eq(1)
      end
    end

    context "with cycle created through cascades referencing each other" do
      it "is caught by the analyzer" do
        msgs = detect(
          x: [:y],
          y: [:x] # cycle x → y → x
        )

        expect(msgs.first).to match(/cycle detected: x → y → x/)
        expect(msgs.size).to eq(1)
      end
    end
  end
end
