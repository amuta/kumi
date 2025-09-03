# frozen_string_literal: true

require "spec_helper"

RSpec.describe "RubyV3 Integration: Dependency Inlining" do
  include PackTestHelper

  it "generates code with proper dependency resolution and inlining" do
    schema = <<~KUMI
      schema do
        input do
          array :employees do
            integer :salary
            integer :rating
          end
        end
        
        value :high_earners, input.employees.salary >= 50000
        value :bonus_eligible, high_earners and input.employees.rating >= 4
      end
    KUMI
    
    pack = pack_for(schema)
    generator = Kumi::Codegen::RubyV3::Generator.new(pack, module_name: "DependencyOps")
    
    generated_code = generator.render
    
    # Should contain loop structure for array processing
    expect(generated_code).to include('arr0 = @input["employees"]')
    expect(generated_code).to include("while i0 < arr0.length")
    
    # Should access both salary and rating fields
    expect(generated_code).to include('a0["salary"]')
    expect(generated_code).to include('a0["rating"]')
    
    # Should contain comparison operations
    expect(generated_code).to include("__call_kernel__")
    expect(generated_code).to include("core.gte")  # >=
    expect(generated_code).to include("core.and")  # &&
    
    # Should contain variable assignments for intermediate results
    expect(generated_code).to match(/v\d+ = /)
    
    # Should yield final computed values
    expect(generated_code).to match(/yield v\d+/)
    
    # Test executable behavior
    eval(generated_code)
    processor = Object.new.extend(DependencyOps)
    input_data = {
      "employees" => [
        { "salary" => 60000, "rating" => 5 },  # high earner + good rating
        { "salary" => 40000, "rating" => 5 },  # low earner + good rating  
        { "salary" => 70000, "rating" => 3 },  # high earner + poor rating
        { "salary" => 30000, "rating" => 2 }   # low earner + poor rating
      ]
    }
    processor.instance_variable_set(:@input, input_data)
    
    # high_earners: [true, false, true, false]
    expect(processor[:high_earners]).to eq([true, false, true, false])
    
    # bonus_eligible: [true, false, false, false] (high earner AND good rating)
    expect(processor[:bonus_eligible]).to eq([true, false, false, false])
  end
end