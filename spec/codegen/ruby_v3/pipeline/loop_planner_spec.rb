# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kumi::Codegen::RubyV3::Pipeline::LoopPlanner do
  describe ".run" do
    context "rank calculation from axes" do
      it "returns axes.length as rank" do
        ctx = {
          axes: ["regions", "offices", "teams", "employees"],
          axis_carriers: []
        }
        
        result = described_class.run(ctx)
        
        expect(result[:rank]).to eq(4)
      end
      
      it "handles scalar (rank 0) declarations" do
        ctx = {
          axes: [],
          axis_carriers: []
        }
        
        result = described_class.run(ctx)
        
        expect(result[:rank]).to eq(0)
      end
    end
    
    context "depth indexing assigns sequential depths starting from 0" do
      it "maps axis_carriers to depth-indexed loops with preserved via_path" do
        ctx = {
          axes: ["regions", "offices", "teams"],
          axis_carriers: [
            { "axis" => "regions", "via_path" => ["regions"] },
            { "axis" => "offices", "via_path" => ["regions", "offices"] },
            { "axis" => "teams", "via_path" => ["regions", "offices", "teams"] }
          ]
        }
        
        result = described_class.run(ctx)
        
        expect(result[:loops]).to eq([
          { depth: 0, via_path: ["regions"] },
          { depth: 1, via_path: ["regions", "offices"] },
          { depth: 2, via_path: ["regions", "offices", "teams"] }
        ])
      end
    end
    
    context "via_path cumulative navigation pattern" do
      it "preserves exact via_path arrays for loop navigation" do
        # This tests the critical pattern: via_path is cumulative
        # depth 0: navigate to ["regions"]
        # depth 1: navigate to ["regions", "offices"] 
        # depth 2: navigate to ["regions", "offices", "teams"]
        ctx = {
          axes: ["batches", "items"],
          axis_carriers: [
            { "axis" => "batches", "via_path" => ["data", "batches"] },
            { "axis" => "items", "via_path" => ["data", "batches", "items"] }
          ]
        }
        
        result = described_class.run(ctx)
        
        loops = result[:loops]
        expect(loops[0][:via_path]).to eq(["data", "batches"])
        expect(loops[1][:via_path]).to eq(["data", "batches", "items"])
        
        # StreamLowerer will use these exact paths for navigation
        # depth 0: @input["data"]["batches"]
        # depth 1: a0["items"]
      end
    end
    
    context "empty axis_carriers for scalar computations" do
      it "returns empty loops array for rank-0 declarations" do
        ctx = {
          axes: [],
          axis_carriers: []
        }
        
        result = described_class.run(ctx)
        
        expect(result[:loops]).to eq([])
        expect(result[:rank]).to eq(0)
      end
    end
  end
end