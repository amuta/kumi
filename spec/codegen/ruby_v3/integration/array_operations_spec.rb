# frozen_string_literal: true

require "spec_helper"

RSpec.describe "RubyV3 Integration: Array Operations" do
  include PackTestHelper

  it "generates code with proper loop structure for single-dimensional arrays" do
    schema = <<~KUMI
      schema do
        input do
          array :items do
            integer :price
          end
        end
        
        value :doubled_prices, input.items.price * 2
      end
    KUMI
    
    pack = pack_for(schema)
    generator = Kumi::Codegen::RubyV3::Generator.new(pack, module_name: "ArrayOps")
    
    generated_code = generator.render
    
    # Should contain proper loop structure
    expect(generated_code).to include('arr0 = @input["items"]')
    expect(generated_code).to include("i0 = 0")
    expect(generated_code).to include("while i0 < arr0.length")
    expect(generated_code).to include("a0 = arr0[i0]")
    expect(generated_code).to include("i0 += 1")
    
    # Should contain field access within loop
    expect(generated_code).to include('a0["price"]')
    
    # Should yield with proper indices
    expect(generated_code).to include("yield ")
    expect(generated_code).to include("[i0]")
    
    # Should use array materialization
    expect(generated_code).to include("__materialize_from_each(:doubled_prices)")
    
    # Test executable behavior
    eval(generated_code)
    processor = Object.new.extend(ArrayOps)
    input_data = { 
      "items" => [
        { "price" => 10 },
        { "price" => 20 },
        { "price" => 30 }
      ]
    }
    processor.instance_variable_set(:@input, input_data)
    
    expect(processor[:doubled_prices]).to eq([20, 40, 60])
  end
end