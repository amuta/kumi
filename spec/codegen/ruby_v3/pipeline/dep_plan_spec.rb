# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kumi::Codegen::RubyV3::Pipeline::DepPlan do
  let(:mock_view) { double("PackView") }
  
  describe ".run" do
    context "pack-driven inlining decisions, not usage heuristics" do
      it "reads inlining_decisions from pack to classify LoadDeclaration ops" do
        allow(mock_view).to receive(:producer_axes).with("target_a").and_return(["axis1"])
        allow(mock_view).to receive(:producer_axes).with("target_b").and_return(["axis1", "axis2"])
        
        ctx = {
          ops: [
            { "id" => 1, "op" => "LoadDeclaration", "args" => ["target_a"] },
            { "id" => 2, "op" => "LoadDeclaration", "args" => ["target_b"] },
            { "id" => 3, "op" => "Map", "args" => [1, 2] }  # Not a LoadDeclaration
          ],
          inline: {
            "op_1" => { "decision" => "inline" },
            "op_2" => { "decision" => "indexed" }
          }
        }
        
        result = described_class.run(mock_view, ctx)
        
        # Pack says op_1 is inline
        expect(result[:inline_ids]).to contain_exactly(1)
        
        # Pack says op_2 is indexed, with producer rank
        expect(result[:indexed]).to eq({ 2 => { name: "target_b", rank: 2 } })
      end
      
      it "delegates producer rank calculation to view.producer_axes" do
        allow(mock_view).to receive(:producer_axes).with("multi_dim_target").and_return(["a", "b", "c"])
        
        ctx = {
          ops: [{ "id" => 5, "op" => "LoadDeclaration", "args" => ["multi_dim_target"] }],
          inline: { "op_5" => { "decision" => "indexed" } }
        }
        
        result = described_class.run(mock_view, ctx)
        
        expect(result[:indexed][5][:rank]).to eq(3)
        expect(mock_view).to have_received(:producer_axes).with("multi_dim_target")
      end
    end
    
    context "filters only LoadDeclaration operations" do
      it "ignores non-LoadDeclaration ops even if they have inlining decisions" do
        ctx = {
          ops: [
            { "id" => 1, "op" => "Map", "args" => [0, 1] },
            { "id" => 2, "op" => "Const", "args" => [42] },
            { "id" => 3, "op" => "LoadInput", "args" => [["x"]] }
          ],
          inline: {
            "op_1" => { "decision" => "inline" },
            "op_2" => { "decision" => "inline" }
          }
        }
        
        result = described_class.run(mock_view, ctx)
        
        expect(result[:inline_ids]).to be_empty
        expect(result[:indexed]).to be_empty
      end
    end
    
    context "missing inlining decisions default to indexed" do
      it "treats LoadDeclaration ops without inlining_decisions as indexed" do
        allow(mock_view).to receive(:producer_axes).with("no_decision_target").and_return(["axis"])
        
        ctx = {
          ops: [{ "id" => 7, "op" => "LoadDeclaration", "args" => ["no_decision_target"] }],
          inline: {}  # No decision for op_7
        }
        
        result = described_class.run(mock_view, ctx)
        
        expect(result[:inline_ids]).to be_empty
        expect(result[:indexed]).to eq({ 7 => { name: "no_decision_target", rank: 1 } })
      end
    end
    
    context "empty operations list" do
      it "returns empty sets when no LoadDeclaration ops exist" do
        ctx = {
          ops: [],
          inline: {}
        }
        
        result = described_class.run(mock_view, ctx)
        
        expect(result[:inline_ids]).to be_empty
        expect(result[:indexed]).to be_empty
      end
    end
  end
end