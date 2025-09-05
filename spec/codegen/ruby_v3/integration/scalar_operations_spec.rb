# frozen_string_literal: true

require "spec_helper"

RSpec.describe "RubyV3 Integration: Scalar Operations" do
  include PackTestHelper

  it "generates code for rank-0 scalar computations without loops" do
    schema = <<~KUMI
      schema do
        input do
          integer :x
          integer :y
        end
        
        value :sum, input.x + input.y
        value :difference, input.x - input.y
      end
    KUMI
    
    pack = pack_for(schema)
    generator = Kumi::Codegen::RubyV3::Generator.new(pack, module_name: "ScalarOps")
    
    generated_code = generator.render
    
    # Should NOT contain loop constructs for scalar operations
    expect(generated_code).not_to include("while")
    expect(generated_code).not_to include("arr0")
    expect(generated_code).not_to include("i0")
    
    # Should contain direct field access
    expect(generated_code).to include('@input["x"]')
    expect(generated_code).to include('@input["y"]')
    
    # Should use rank-0 materialization (direct return)
    expect(generated_code).to include("_each_sum { |value, _| return value }")
    expect(generated_code).to include("_each_difference { |value, _| return value }")
    
    # Test executable behavior
    eval(generated_code)
    calculator = Object.new.extend(ScalarOps)
    calculator.instance_variable_set(:@input, { "x" => 10, "y" => 3 })
    
    expect(calculator[:sum]).to eq(13)
    expect(calculator[:difference]).to eq(7)
  end
end