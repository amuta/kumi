# frozen_string_literal: true

require "spec_helper"

RSpec.describe "RubyV3 Integration: Multi-dimensional Arrays" do
  include PackTestHelper

  it "handles nested array navigation with multiple depths" do
    schema = <<~KUMI
      schema do
        input do
          array :regions do
            array :offices do
              array :teams do
                integer :headcount
              end
            end
          end
        end
        
        value :headcount_data, input.regions.offices.teams.headcount
      end
    KUMI
    
    pack = pack_for(schema)
    generator = Kumi::Codegen::RubyV3::Generator.new(pack, module_name: "MultiDim")
    
    result = generator.render
    
    # Should generate nested loops for 3 levels
    expect(result).to include("arr0 = @input[\"regions\"]")
    expect(result).to include("arr1 = a0[\"offices\"]") 
    expect(result).to include("arr2 = a1[\"teams\"]")
    
    # Should handle deep field navigation
    expect(result).to include("a2[\"headcount\"]")
  end
end