RSpec.describe Kumi::Analyzer::Passes::CycleDetector do
  def detect(graph)
    state  = { dependency_graph: graph }
    errors = []
    described_class.new(nil, state).run(errors)
    errors.map(&:last)                 # return just the messages
  end

  describe ".run" do
    context "acyclic graph" do
      it "records no errors" do
        expect(detect(a: %i[b], b: [])).to be_empty
      end
    end

    context "self-loop" do
      it "detects a node that references itself" do
        msgs = detect(a: %i[a])
        expect(msgs.first).to match(/cycle detected: a → a/)
      end
    end

    context "two-node cycle" do
      it "detects a ↔ b" do
        msgs = detect(a: %i[b], b: %i[a])
        expect(msgs.first).to match(/cycle detected: a → b → a/)
      end
    end

    context "three-node ring" do
      it "detects a → b → c → a" do
        msgs = detect(a: %i[b], b: %i[c], c: %i[a])
        expect(msgs.first).to match(/cycle detected: a → b → c → a/)
      end
    end

    context "multiple disconnected cycles" do
      it "reports at least one message per cycle" do
        graph = {
          a: %i[b], b: %i[a],          # cycle 1
          x: %i[y], y: %i[x],          # cycle 2
          k: []                        # acyclic node
        }
        msgs = detect(graph)

        expect(msgs.size).to be >= 2
        expect(msgs.any? { |m| m.match?(/a → b → a/) }).to be true
        expect(msgs.any? { |m| m.match?(/x → y → x/) }).to be true
      end
    end

    context "cycle plus acyclic subgraph" do
      it "ignores acyclic parts and flags the cycle" do
        graph = { a: %i[b], b: %i[a], # cycle
                  c: %i[d], d: [] } # acyclic chain
        msgs = detect(graph)

        expect(msgs.first).to match(/cycle detected: a → b → a/)
        expect(msgs.size).to eq(1)
      end
    end

    context "cycle created through cascades referencing each other" do
      it "is caught by the analyzer" do
        graph = {
          x: %i[y],
          y: %i[x] # cycle x → y → x
        }
        msgs = detect(graph)

        expect(msgs.first).to match(/cycle detected: x → y → x/)
        expect(msgs.size).to eq(1)
      end
    end
  end
end
