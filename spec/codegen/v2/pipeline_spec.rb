# frozen_string_literal: true

require_relative "../../../lib/kumi/codegen/v2/pipeline/pack_sanity"
require_relative "../../../lib/kumi/codegen/v2/pipeline/kernel_index"

RSpec.describe "Codegen V2 Pipeline" do
  include PackTestHelper

  let(:simple_schema) do
    <<~SCHEMA
      schema do
        input do
          integer :x
        end
        
        value :result, input.x + 1
      end
    SCHEMA
  end

  let(:pack) { pack_for(simple_schema) }

  describe "PackSanity" do
    it "validates pack structure" do
      expect(Kumi::Codegen::V2::Pipeline::PackSanity.run(pack)).to eq(true)
    end

    it "raises on missing required fields" do
      incomplete_pack = pack.except("plan")
      expect { Kumi::Codegen::V2::Pipeline::PackSanity.run(incomplete_pack) }
        .to raise_error(KeyError, "missing plan")
    end
  end

  describe "KernelIndex" do
    it "extracts kernel implementations for ruby target" do
      kernels = Kumi::Codegen::V2::Pipeline::KernelIndex.run(pack, target: "ruby")
      expect(kernels).to be_a(Hash)
      expect(kernels.keys).to all(be_a(String))
      expect(kernels.values).to all(be_a(String))
    end

    it "returns empty hash when no kernels present" do
      pack_without_kernels = pack.dup
      pack_without_kernels["bindings"]["ruby"].delete("kernels") if pack_without_kernels.dig("bindings", "ruby")
      kernels = Kumi::Codegen::V2::Pipeline::KernelIndex.run(pack_without_kernels, target: "ruby")
      expect(kernels).to eq({})
    end
  end
end