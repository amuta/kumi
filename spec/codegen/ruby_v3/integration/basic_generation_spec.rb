# frozen_string_literal: true

require "spec_helper"

RSpec.describe "RubyV3 Integration: Basic Generation" do
  include PackTestHelper

  it "generates Ruby module from simple schema without crashing" do
    schema = <<~KUMI
      schema do
        input do
          integer :x
        end
        
        value :double, input.x * 2
      end
    KUMI
    
    pack = pack_for(schema)
    generator = Kumi::Codegen::RubyV3::Generator.new(pack, module_name: "TestModule")
    
    result = generator.render
    
    expect(result).to be_a(String)
    expect(result).to include("module TestModule")
  end
end