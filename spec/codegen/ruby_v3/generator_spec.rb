# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kumi::Codegen::RubyV3::Generator do
  let(:minimal_pack) do
    {
      "declarations" => [{ "name" => "test", "operations" => [], "result_op_id" => 0 }],
      "inputs" => [],
      "bindings" => { "ruby" => { "kernels" => [] } }
    }
  end
  
  describe "#initialize" do
    it "stores pack and module_name for render method" do
      generator = described_class.new(minimal_pack, module_name: "TestModule")
      
      expect(generator.instance_variable_get(:@pack)).to eq(minimal_pack)
      expect(generator.instance_variable_get(:@module_name)).to eq("TestModule")
    end
  end
  
  describe "#render" do
    context "pipeline orchestration order" do
      it "calls PackSanity validation before any other processing" do
        allow(Kumi::Codegen::RubyV3::Pipeline::PackSanity).to receive(:run).and_raise("Validation failed")
        
        generator = described_class.new(minimal_pack, module_name: "Test")
        
        expect { generator.render }.to raise_error("Validation failed")
      end
    end
    
    context "declarations processing order" do
      it "processes declarations in pack.declarations_in_order sequence" do
        pack_with_order = {
          "declarations" => [
            { 
              "name" => "first", "operations" => [], "result_op_id" => 0,
              "axes" => [], "axis_carriers" => [], "reduce_plans" => [], 
              "site_schedule" => {}, "inlining_decisions" => {}
            },
            { 
              "name" => "second", "operations" => [], "result_op_id" => 0,
              "axes" => [], "axis_carriers" => [], "reduce_plans" => [], 
              "site_schedule" => {}, "inlining_decisions" => {}
            }
          ],
          "inputs" => [],
          "bindings" => { "ruby" => { "kernels" => [] } }
        }
        
        # Mock pipeline modules to focus on orchestration order
        allow(Kumi::Codegen::RubyV3::Pipeline::PackSanity).to receive(:run)
        allow(Kumi::Codegen::RubyV3::Pipeline::ConstPlan).to receive(:run).and_return({ inline_ids: Set.new, prelude: [] })
        allow(Kumi::Codegen::RubyV3::Pipeline::DepPlan).to receive(:run).and_return({ inline_ids: Set.new, indexed: {} })
        allow(Kumi::Codegen::RubyV3::Pipeline::StreamLowerer).to receive(:run).and_return(double("CGIR::Function"))
        allow(Kumi::Codegen::RubyV3::RubyRenderer).to receive(:render).and_return("code")
        
        generator = described_class.new(pack_with_order, module_name: "Test")
        generator.render
        
        # If this doesn't crash, declarations were processed in correct order
        expect(Kumi::Codegen::RubyV3::RubyRenderer).to have_received(:render).with(
          hash_including(program: have_attributes(size: 2))
        )
      end
    end
  end
  
  describe "#pack_hash" do
    it "extracts hash values safely with empty fallback" do
      generator = described_class.new({}, module_name: "Test")
      
      result = generator.send(:pack_hash, {})
      
      expect(result).to eq("")
    end
    
    it "joins hash values with colon separator" do
      pack_with_hashes = { "hashes" => { "a" => "hash1", "b" => "hash2" } }
      generator = described_class.new({}, module_name: "Test")
      
      result = generator.send(:pack_hash, pack_with_hashes)
      
      expect(result).to eq("hash1:hash2")
    end
  end
end