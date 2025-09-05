# frozen_string_literal: true

require "spec_helper"

RSpec.describe "RubyV3 Integration: Method Generation" do
  include PackTestHelper

  it "generates _each_ and _eval_ methods for each declaration" do
    schema = <<~KUMI
      schema do
        input do
          integer :x
          integer :y
        end
        
        value :sum, input.x + input.y
        value :product, input.x * input.y
      end
    KUMI
    
    pack = pack_for(schema)
    generator = Kumi::Codegen::RubyV3::Generator.new(pack, module_name: "TestModule")
    
    result = generator.render
    
    expect(result).to include("def _each_sum")
    expect(result).to include("def _eval_sum")
    expect(result).to include("def _each_product")
    expect(result).to include("def _eval_product")
  end
end