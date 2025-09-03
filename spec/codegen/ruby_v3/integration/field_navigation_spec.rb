# frozen_string_literal: true

require "spec_helper"

RSpec.describe "RubyV3 Integration: Complex Field Navigation" do
  include PackTestHelper

  it "handles deep field access through nested structures" do
    schema = <<~KUMI
      schema do
        input do
          array :depts do
            array :teams do
              integer :headcount
              string :name
            end
          end
        end
        
        value :team_sizes, input.depts.teams.headcount
        value :team_names, input.depts.teams.name
      end
    KUMI
    
    pack = pack_for(schema)
    generator = Kumi::Codegen::RubyV3::Generator.new(pack, module_name: "Navigation")
    
    result = generator.render
    
    # Should navigate through dept -> team hierarchy
    expect(result).to include("arr0 = @input[\"depts\"]")
    expect(result).to include("arr1 = a0[\"teams\"]")
    
    # Should access different fields from same level
    expect(result).to include("a1[\"headcount\"]")
    expect(result).to include("a1[\"name\"]")
  end
end