# frozen_string_literal: true

require "spec_helper"

RSpec.describe "RubyV3 Integration: Executable Ruby Code" do
  include PackTestHelper

  it "generates Ruby code that can be instantiated and executed" do
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
    generator = Kumi::Codegen::RubyV3::Generator.new(pack, module_name: "Calculator")
    
    generated_code = generator.render
    
    # Eval the generated code to create the module
    eval(generated_code)
    
    # Create an object that extends the module with input data
    input_data = { "x" => 5, "y" => 3 }
    calculator = Object.new
    calculator.extend(Calculator)
    calculator.instance_variable_set(:@input, input_data)
    
    # Test the generated methods work
    expect(calculator[:sum]).to eq(8)     # 5 + 3
    expect(calculator[:product]).to eq(15) # 5 * 3
  end
end