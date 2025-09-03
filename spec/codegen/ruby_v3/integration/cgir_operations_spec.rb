# frozen_string_literal: true

require "spec_helper"

RSpec.describe "RubyV3 Integration: CGIR Operations Processing" do
  include PackTestHelper

  it "processes CGIR operations without crashing and generates operation comments" do
    schema = <<~KUMI
      schema do
        input do
          integer :x
          integer :y
        end
        
        value :calculation, input.x + input.y * 2
      end
    KUMI
    
    pack = pack_for(schema)
    generator = Kumi::Codegen::RubyV3::Generator.new(pack, module_name: "TestModule")
    
    result = generator.render
    
    # Should contain CGIR operation comments (since renderer is stub)
    expect(result).to include("# TODO: Implement streaming method")
    expect(result).to include("# TODO: Implement materialization")
    
    # Should handle all operations without throwing unhandled case errors
    expect(result).not_to include("NoMethodError")
    expect(result).not_to include("unhandled")
  end
end