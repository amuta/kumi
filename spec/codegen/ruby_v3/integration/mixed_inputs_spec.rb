# frozen_string_literal: true

require "spec_helper"

RSpec.describe "RubyV3 Integration: Mixed Scalar and Array Inputs" do
  include PackTestHelper

  it "handles schemas with both scalar and array inputs" do
    schema = <<~KUMI
      schema do
        input do
          array :items do
            float :price
          end
          float :tax_rate
        end
        
        value :taxed_price, input.items.price * (1.0 + input.tax_rate)
      end
    KUMI
    
    pack = pack_for(schema)
    generator = Kumi::Codegen::RubyV3::Generator.new(pack, module_name: "MixedInputs")
    
    result = generator.render
    
    # Should handle array field navigation
    expect(result).to include("a0[\"price\"]")
    
    # Should handle scalar field access 
    expect(result).to include("@input[\"tax_rate\"]")
    
    # Should contain arithmetic operations
    expect(result).to include("__call_kernel__")
  end
end