# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kumi::Codegen::RubyV3::Pipeline::PackView do
  let(:simple_math_pack) do
    JSON.parse(File.read("golden/simple_math/expected/pack.json"))
  end
  
  let(:pack_view) { described_class.new(simple_math_pack) }
  
  describe "#declarations_in_order" do
    it "returns declaration names in pack order" do
      expect(pack_view.declarations_in_order).to eq(["difference", "product", "results_array", "sum"])
    end
  end
  
  describe "#decl_spec" do
    it "extracts operations and result_op_id" do
      spec = pack_view.decl_spec("sum")
      
      expect(spec[:operations]).to be_an(Array)
      expect(spec[:operations].size).to eq(3)
      expect(spec[:result_op_id]).to eq(2)
    end
  end
  
  describe "#decl_plan" do
    it "extracts execution plan data" do
      plan = pack_view.decl_plan("sum")
      
      expect(plan[:axes]).to eq([])
      expect(plan[:axis_carriers]).to eq([])
      expect(plan[:site_schedule]).to be_a(Hash)
      expect(plan[:site_schedule]["by_depth"]).to be_an(Array)
    end
  end
  
  describe "#input_chain_by_path" do
    it "finds chain for simple field path" do
      chain = pack_view.input_chain_by_path(["x"])
      
      expect(chain).to be_an(Array)
      expect(chain.size).to eq(1)
      expect(chain[0]["kind"]).to eq("field_leaf")
      expect(chain[0]["key"]).to eq("x")
    end
    
    it "raises clear KeyError when path not found" do
      expect { pack_view.input_chain_by_path(["nonexistent"]) }
        .to raise_error(KeyError, 'Chain not found for path: ["nonexistent"]')
    end
  end
end