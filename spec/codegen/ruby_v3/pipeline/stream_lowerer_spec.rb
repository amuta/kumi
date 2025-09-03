# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kumi::Codegen::RubyV3::Pipeline::StreamLowerer do
  describe ".emit_chain_access" do
    context "Issue #2 fix: chain navigation counts array_fields, not declaration rank" do
      it "uses @input when no array_field steps in chain" do
        chain = [{ "kind" => "field_leaf", "key" => "price" }]
        
        result = described_class.emit_chain_access(chain, 0, 2)
        
        expect(result).to eq('@input["price"]')
      end
      
      it "uses a0 when 1 array_field step in chain" do
        chain = [
          { "kind" => "array_field", "key" => "items" },
          { "kind" => "field_leaf", "key" => "price" }
        ]
        
        result = described_class.emit_chain_access(chain, 1, 2)
        
        expect(result).to eq('a0["price"]')
      end
      
      it "uses a1 when 2 array_field steps in chain" do
        chain = [
          { "kind" => "array_field", "key" => "batches" },
          { "kind" => "array_field", "key" => "items" },
          { "kind" => "field_leaf", "key" => "price" }
        ]
        
        result = described_class.emit_chain_access(chain, 2, 3)
        
        expect(result).to eq('a1["price"]')
      end
      
      it "builds nested field access correctly" do
        chain = [
          { "kind" => "field_leaf", "key" => "user" },
          { "kind" => "field_leaf", "key" => "profile" },
          { "kind" => "field_leaf", "key" => "name" }
        ]
        
        result = described_class.emit_chain_access(chain, 0, 1)
        
        expect(result).to eq('@input["user"]["profile"]["name"]')
      end
    end
  end
  
  describe ".run with reductions" do
    let(:mock_view) { double("PackView") }
    let(:loop_shape) { { rank: 1, loops: [] } }
    let(:consts) { { inline_ids: Set.new, prelude: [] } }
    let(:deps) { { inline_ids: Set.new, indexed: {} } }
    
    context "reduction identity values and two-phase wiring" do
      it "creates AccReset with identity at reduce depth, AccAdd at value depth" do
        identities = { "agg.sum" => 0, "agg.mul" => 1 }
        ctx = {
          name: "test",
          result_id: 2,
          ops: [
            { "id" => 1, "op" => "LoadInput", "args" => [["values"]] },
            { "id" => 2, "op" => "Reduce", "args" => [1], "attrs" => { "fn" => "agg.sum" } }
          ],
          reduce_plans: [
            { "op_id" => 2, "arg_id" => 1, "reducer_fn" => "agg.sum" }
          ],
          site_schedule: {
            "by_depth" => [
              { "depth" => 1, "ops" => [{ "id" => 1, "kind" => "loadinput" }] },
              { "depth" => 0, "ops" => [{ "id" => 2, "kind" => "reduce" }] }
            ]
          }
        }
        
        allow(mock_view).to receive(:input_chain_by_path).and_return([{ "kind" => "field_leaf", "key" => "values" }])
        
        result = described_class.run(mock_view, ctx, loop_shape:, consts:, deps:, identities:)
        
        # AccReset at reduce depth (0) with correct identity
        acc_reset = result.ops.find { |op| op[:k] == :AccReset }
        expect(acc_reset[:depth]).to eq(0)
        expect(acc_reset[:init]).to eq(0)
        expect(acc_reset[:name]).to eq("acc_2")
        
        # AccAdd at value depth (1)
        acc_add = result.ops.find { |op| op[:k] == :AccAdd }
        expect(acc_add[:depth]).to eq(1)
        expect(acc_add[:expr]).to eq("v1")
        expect(acc_add[:name]).to eq("acc_2")
      end
    end
    
    context "result yield depth is pack-driven, not guessed" do
      it "yields at result operation's scheduled depth, not [rank-1, 0].max" do
        ctx = {
          name: "test",
          result_id: 5,
          reduce_plans: [],
          ops: [{ "id" => 5, "op" => "Map", "args" => [1, 2], "attrs" => { "fn" => "core.add" } }],
          site_schedule: {
            "by_depth" => [
              { "depth" => 3, "ops" => [{ "id" => 5, "kind" => "map" }] }
            ]
          }
        }
        
        result = described_class.run(mock_view, ctx, loop_shape:, consts:, deps:, identities: {})
        
        yield_op = result.ops.find { |op| op[:k] == :Yield }
        expect(yield_op[:depth]).to eq(3)  # Pack says depth 3, not rank-1=0
      end
    end
  end
  
  describe ".run with LoadInput" do
    let(:mock_view) { double("PackView") }
    let(:loop_shape) { { rank: 0, loops: [] } }
    let(:consts) { { inline_ids: Set.new, prelude: [] } }
    let(:deps) { { inline_ids: Set.new, indexed: {} } }
    
    context "LoadInput delegates to chain resolution" do
      it "calls view.input_chain_by_path and emit_chain_access for field navigation" do
        chain = [{ "kind" => "field_leaf", "key" => "x" }]
        allow(mock_view).to receive(:input_chain_by_path).with(["x"]).and_return(chain)
        
        ctx = {
          name: "test", 
          result_id: 0,
          reduce_plans: [],
          ops: [{ "id" => 0, "op" => "LoadInput", "args" => [["x"]] }],
          site_schedule: {
            "by_depth" => [{ "depth" => 0, "ops" => [{ "id" => 0, "kind" => "loadinput" }] }]
          }
        }
        
        result = described_class.run(mock_view, ctx, loop_shape:, consts:, deps:, identities: {})
        
        load_op = result.ops.find { |op| op[:k] == :Emit && op[:code].include?("v0") }
        expect(load_op[:code]).to eq('v0 = @input["x"]')
        expect(mock_view).to have_received(:input_chain_by_path).with(["x"])
      end
    end
  end
end