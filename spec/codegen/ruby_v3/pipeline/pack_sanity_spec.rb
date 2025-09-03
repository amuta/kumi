# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kumi::Codegen::RubyV3::Pipeline::PackSanity do
  describe ".run" do
    context "pack structure validation with clear error messages" do
      it "requires pack['declarations'] to be an Array" do
        pack_no_declarations = {}
        
        expect { described_class.run(pack_no_declarations) }.to raise_error(KeyError, "declarations missing")
      end
      
      it "requires pack['inputs'] to be an Array" do
        pack_no_inputs = { "declarations" => [] }
        
        expect { described_class.run(pack_no_inputs) }.to raise_error(KeyError, "inputs missing")
      end
      
      it "rejects non-Array declarations field" do
        pack_hash_declarations = { "declarations" => {}, "inputs" => [] }
        
        expect { described_class.run(pack_hash_declarations) }.to raise_error(KeyError, "declarations missing")
      end
      
      it "rejects non-Array inputs field" do
        pack_hash_inputs = { "declarations" => [], "inputs" => {} }
        
        expect { described_class.run(pack_hash_inputs) }.to raise_error(KeyError, "inputs missing")
      end
    end
    
    context "successful validation returns true" do
      it "returns true when pack has required Array fields" do
        valid_pack = { "declarations" => [], "inputs" => [] }
        
        result = described_class.run(valid_pack)
        
        expect(result).to be(true)
      end
    end
  end
end