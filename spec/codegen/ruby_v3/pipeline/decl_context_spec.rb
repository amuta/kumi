# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kumi::Codegen::RubyV3::Pipeline::DeclContext do
  let(:mock_view) { double("PackView") }
  
  describe ".run" do
    context "PackView delegation for spec and plan data" do
      it "calls view.decl_spec and view.decl_plan with declaration name" do
        allow(mock_view).to receive(:decl_spec).with("target").and_return({ operations: [], result_op_id: 0 })
        allow(mock_view).to receive(:decl_plan).with("target").and_return({ 
          axes: [], axis_carriers: [], reduce_plans: [], site_schedule: {}, inlining_decisions: {} 
        })
        
        described_class.run(mock_view, "target")
        
        expect(mock_view).to have_received(:decl_spec).with("target").once
        expect(mock_view).to have_received(:decl_plan).with("target").once
      end
    end
    
    context "context key mapping from PackView responses" do
      it "maps spec.operations → ctx[:ops] and spec.result_op_id → ctx[:result_id]" do
        operations = [{ "id" => 5, "op" => "Const", "args" => [42] }]
        
        allow(mock_view).to receive(:decl_spec).and_return({ operations: operations, result_op_id: 5 })
        allow(mock_view).to receive(:decl_plan).and_return({ 
          axes: [], axis_carriers: [], reduce_plans: [], 
          site_schedule: {}, inlining_decisions: {} 
        })
        
        result = described_class.run(mock_view, "test")
        
        expect(result[:ops]).to eq(operations)
        expect(result[:result_id]).to eq(5)
      end
      
      it "maps plan.inlining_decisions → ctx[:inline] for DepPlan consumption" do
        inlining_decisions = { "op_1" => { "decision" => "inline" } }
        
        allow(mock_view).to receive(:decl_spec).and_return({ operations: [], result_op_id: 0 })
        allow(mock_view).to receive(:decl_plan).and_return({ 
          axes: [], axis_carriers: [], reduce_plans: [], 
          site_schedule: {}, inlining_decisions: inlining_decisions 
        })
        
        result = described_class.run(mock_view, "test")
        
        expect(result[:inline]).to eq(inlining_decisions)
      end
      
      it "preserves plan.axes and plan.axis_carriers for LoopPlanner consumption" do
        axes = ["regions", "offices"]
        axis_carriers = [{ "axis" => "regions", "via_path" => ["regions"] }]
        
        allow(mock_view).to receive(:decl_spec).and_return({ operations: [], result_op_id: 0 })
        allow(mock_view).to receive(:decl_plan).and_return({ 
          axes: axes, axis_carriers: axis_carriers, reduce_plans: [], 
          site_schedule: {}, inlining_decisions: {} 
        })
        
        result = described_class.run(mock_view, "test")
        
        expect(result[:axes]).to eq(axes)
        expect(result[:axis_carriers]).to eq(axis_carriers)
      end
      
      it "preserves plan.site_schedule for ConstPlan and StreamLowerer consumption" do
        site_schedule = { "by_depth" => [{ "depth" => 0, "ops" => [] }] }
        
        allow(mock_view).to receive(:decl_spec).and_return({ operations: [], result_op_id: 0 })
        allow(mock_view).to receive(:decl_plan).and_return({ 
          axes: [], axis_carriers: [], reduce_plans: [], 
          site_schedule: site_schedule, inlining_decisions: {} 
        })
        
        result = described_class.run(mock_view, "test")
        
        expect(result[:site_schedule]).to eq(site_schedule)
      end
      
      it "preserves plan.reduce_plans for StreamLowerer reduction handling" do
        reduce_plans = [{ "op_id" => 1, "arg_id" => 0, "reducer_fn" => "agg.sum" }]
        
        allow(mock_view).to receive(:decl_spec).and_return({ operations: [], result_op_id: 0 })
        allow(mock_view).to receive(:decl_plan).and_return({ 
          axes: [], axis_carriers: [], reduce_plans: reduce_plans, 
          site_schedule: {}, inlining_decisions: {} 
        })
        
        result = described_class.run(mock_view, "test")
        
        expect(result[:reduce_plans]).to eq(reduce_plans)
      end
    end
    
    context "unified context structure for pipeline modules" do
      it "includes declaration name in context for identification" do
        allow(mock_view).to receive(:decl_spec).and_return({ operations: [], result_op_id: 0 })
        allow(mock_view).to receive(:decl_plan).and_return({ 
          axes: [], axis_carriers: [], reduce_plans: [], site_schedule: {}, inlining_decisions: {} 
        })
        
        result = described_class.run(mock_view, "test_name")
        
        expect(result[:name]).to eq("test_name")
      end
      
      it "provides complete context hash with all required keys for pipeline" do
        allow(mock_view).to receive(:decl_spec).and_return({ operations: [], result_op_id: 0 })
        allow(mock_view).to receive(:decl_plan).and_return({ 
          axes: [], axis_carriers: [], reduce_plans: [], site_schedule: {}, inlining_decisions: {} 
        })
        
        result = described_class.run(mock_view, "test")
        
        # All pipeline modules expect these exact keys
        expect(result.keys).to contain_exactly(
          :name, :axes, :axis_carriers, :reduce_plans, :site_schedule, 
          :inline, :ops, :result_id
        )
      end
    end
  end
end