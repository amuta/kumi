# frozen_string_literal: true

require "spec_helper"

RSpec.describe "RubyV3 Integration: Element Arrays" do
  include PackTestHelper

  it "handles nested element arrays with complex reductions" do
    schema = <<~KUMI
      schema do
        input do
          array :cube do
            element :array, :layer do
              element :array, :row do
                element :integer, :cell
              end
            end
          end
        end

        value :cube,  input.cube
        value :layer, input.cube.layer
        value :row, input.cube.layer.row
        value :cell, input.cube.layer.row.cell

        trait :cell_over_limit, input.cube.layer.row.cell > 100

        value :cell_sum, fn(:sum_if, input.cube.layer.row.cell, cell_over_limit)
        value :count_over_limit, fn(:sum, fn(:sum, fn(:sum_if, 1, cell_over_limit)))
      end
    KUMI

    pack = pack_for(schema)
    generator = Kumi::Codegen::RubyV3::Generator.new(pack, module_name: "ElementArrays")
    
    # Should be able to generate code without crashing
    generated_code = generator.render
    expect(generated_code).to be_a(String)
    expect(generated_code).to include("module ElementArrays")
    
    # Should handle nested array navigation
    expect(generated_code).to include("cube")
    expect(generated_code).to include("layer") 
    expect(generated_code).to include("row")
    expect(generated_code).to include("cell")
  end
end