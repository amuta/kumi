# frozen_string_literal: true

require "spec_helper"

RSpec.describe "RubyV3 Integration: Actual Ruby Generation" do
  include PackTestHelper

  it "generates working Ruby code that can be evaluated" do
    schema = <<~KUMI
      schema do
        input do
          integer :x
          integer :y
        end
        
        value :sum, input.x + input.y
      end
    KUMI
    
    pack = pack_for(schema)
    generator = Kumi::Codegen::RubyV3::Generator.new(pack, module_name: "TestModule")
    
    result = generator.render
    
    # Should generate actual Ruby code, not just comments
    expect(result).to include("def _each_sum")
    expect(result).to include("def _eval_sum")
    expect(result).to include("def [](name)")
    expect(result).to include("def __call_kernel__")
    
    # Should contain actual code statements
    expect(result).to include("yield ")
    expect(result).to match(/v\d+ = /)  # Variable assignments
  end

  it "generates kernel dispatch code with actual implementations" do
    schema = <<~KUMI
      schema do
        input do
          integer :a
          integer :b
        end
        
        value :result, input.a + input.b
      end
    KUMI
    
    pack = pack_for(schema)
    generator = Kumi::Codegen::RubyV3::Generator.new(pack, module_name: "MathModule")
    
    result = generator.render
    
    # Should contain kernel implementations from pack
    expect(result).to include("def __call_kernel__")
    expect(result).to match(/return \(.*\)\.call\(\*args\)/)  # Kernel dispatch
  end
end