# frozen_string_literal: true

require "spec_helper"

RSpec.describe "RubyV3 Integration: Nested Array Navigation" do
  include PackTestHelper

  it "generates code with proper nested loop structure and chain navigation" do
    schema = <<~KUMI
      schema do
        input do
          array :departments do
            array :teams do
              integer :headcount
            end
          end
        end
        
        value :all_headcounts, input.departments.teams.headcount
      end
    KUMI
    
    pack = pack_for(schema)
    generator = Kumi::Codegen::RubyV3::Generator.new(pack, module_name: "NestedArrayOps")
    
    generated_code = generator.render
    
    # Should contain outer loop (depth 0)
    expect(generated_code).to include('arr0 = @input["departments"]')
    expect(generated_code).to include("i0 = 0")
    expect(generated_code).to include("while i0 < arr0.length")
    expect(generated_code).to include("a0 = arr0[i0]")
    
    # Should contain inner loop (depth 1)
    expect(generated_code).to include('arr1 = a0["teams"]')
    expect(generated_code).to include("i1 = 0") 
    expect(generated_code).to include("while i1 < arr1.length")
    expect(generated_code).to include("a1 = arr1[i1]")
    
    # Should access nested field correctly
    expect(generated_code).to include('a1["headcount"]')
    
    # Should yield with nested indices
    expect(generated_code).to include("yield ")
    expect(generated_code).to include("[i0, i1]")
    
    # Should close loops in reverse order
    expect(generated_code).to include("i1 += 1")
    expect(generated_code).to include("i0 += 1")
    
    # Test executable behavior
    eval(generated_code)
    processor = Object.new.extend(NestedArrayOps)
    input_data = {
      "departments" => [
        { "teams" => [{ "headcount" => 5 }, { "headcount" => 8 }] },
        { "teams" => [{ "headcount" => 3 }, { "headcount" => 12 }] }
      ]
    }
    processor.instance_variable_set(:@input, input_data)
    
    expected = [[5, 8], [3, 12]]  # Nested structure preserved
    expect(processor[:all_headcounts]).to eq(expected)
  end
end