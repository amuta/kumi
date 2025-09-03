# frozen_string_literal: true

require "spec_helper"

RSpec.describe "RubyV3 Integration: Pack Hash Embedding" do
  include PackTestHelper

  it "embeds pack hash in generated module comment" do
    schema = <<~KUMI
      schema do
        input do
          integer :value
        end
        
        value :result, input.value
      end
    KUMI
    
    pack = pack_for(schema)
    generator = Kumi::Codegen::RubyV3::Generator.new(pack, module_name: "TestModule")
    
    result = generator.render
    
    # Should contain pack hash from pack["hashes"] values
    expect(result).to match(/# Generated code with pack hash: \w+/)
  end
end