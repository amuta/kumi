# frozen_string_literal: true

require "spec_helper"

RSpec.describe "RubyV3 Integration: Constructor Tuple Operations" do
  include PackTestHelper

  it "generates code that constructs arrays from multiple expressions" do
    schema = <<~KUMI
      schema do
        input do
          integer :x
          integer :y
        end
        
        value :triple, [input.x, input.x + input.y, input.y * 2]
      end
    KUMI
    
    pack = pack_for(schema)
    generator = Kumi::Codegen::RubyV3::Generator.new(pack, module_name: "TupleOps")
    
    generated_code = generator.render
    
    # Should contain array construction with multiple expressions
    expect(generated_code).to match(/v\d+ = \[v\d+, v\d+, v\d+\]/)
    
    # Should contain individual expression calculations
    expect(generated_code).to include('@input["x"]')
    expect(generated_code).to include('@input["y"]')
    
    # Should contain addition and multiplication operations
    expect(generated_code).to include("__call_kernel__")
    
    # Should yield the constructed tuple
    expect(generated_code).to match(/yield v\d+/)
    
    # Test executable behavior
    eval(generated_code)
    constructor = Object.new.extend(TupleOps)
    constructor.instance_variable_set(:@input, { "x" => 5, "y" => 3 })
    
    # Should return [5, 8, 6] = [x, x+y, y*2] = [5, 5+3, 3*2]
    expect(constructor[:triple]).to eq([5, 8, 6])
  end
end