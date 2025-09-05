# frozen_string_literal: true

require "spec_helper"

RSpec.describe "RubyV3 Integration: Reduction Operations" do
  include PackTestHelper

  it "generates code with proper accumulator initialization and reduction logic" do
    schema = <<~KUMI
      schema do
        input do
          array :numbers do
            integer :value
          end
        end
        
        value :total, fn(:sum, input.numbers.value)
      end
    KUMI
    
    pack = pack_for(schema)
    generator = Kumi::Codegen::RubyV3::Generator.new(pack, module_name: "ReductionOps")
    
    generated_code = generator.render
    
    # Should contain accumulator reset (identity value issue to be fixed separately)
    expect(generated_code).to match(/acc_\d+ = /)
    
    # Should contain accumulator addition
    expect(generated_code).to match(/acc_\d+ \+= v\d+/)
    
    # Should contain loop structure for reduction
    expect(generated_code).to include('arr0 = @input["numbers"]')
    expect(generated_code).to include("while i0 < arr0.length")
    
    # Should access field being reduced
    expect(generated_code).to include('a0["value"]')
    
    # Should yield the final accumulated result
    expect(generated_code).to match(/yield v\d+/)
    
    # Test executable behavior  
    eval(generated_code)
    reducer = Object.new.extend(ReductionOps)
    input_data = { 
      "numbers" => [
        { "value" => 10 },
        { "value" => 20 },
        { "value" => 30 }
      ]
    }
    reducer.instance_variable_set(:@input, input_data)
    
    expect(reducer[:total]).to eq(60)  # 10 + 20 + 30
  end
end