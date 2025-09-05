# frozen_string_literal: true

require "spec_helper"

RSpec.describe "RubyV3 Integration: Cross Declaration Dependencies" do
  include PackTestHelper

  it "handles dependencies between declarations correctly" do
    schema = <<~KUMI
      schema do
        input do
          integer :x
          integer :y
        end

        value :sum, input.x + input.y
        value :product, input.x * input.y
        value :difference, input.x - input.y
        value :results_array, [1, input.x + 10, input.y * 2, product]
      end
    KUMI

    pack = pack_for(schema)
    generator = Kumi::Codegen::RubyV3::Generator.new(pack, module_name: "CrossDeps")
    
    generated_code = generator.render
    
    # Should generate code that references other declarations
    expect(generated_code).to include("self[:product]")
    expect(generated_code).to include("def _each_product")
    expect(generated_code).to include("def _each_results_array")
    
    # Test that the generated code actually works
    eval(generated_code)
    
    calculator = CrossDeps.from({ "x" => 5, "y" => 3 })
    
    # Test individual values
    expect(calculator[:sum]).to eq(8)
    expect(calculator[:product]).to eq(15) 
    expect(calculator[:difference]).to eq(2)
    
    # Test cross-declaration dependency
    expected_results_array = [1, 15, 6, 15] # [1, x+10, y*2, product]
    expect(calculator[:results_array]).to eq(expected_results_array)
  end

  it "handles multiple levels of dependencies" do
    schema = <<~KUMI
      schema do
        input do
          integer :base
        end

        value :doubled, input.base * 2
        value :squared, doubled * doubled  
        value :final, squared + doubled + input.base
      end
    KUMI

    pack = pack_for(schema)
    generator = Kumi::Codegen::RubyV3::Generator.new(pack, module_name: "MultiDeps")
    
    generated_code = generator.render
    
    # Should reference intermediate declarations
    expect(generated_code).to include("self[:doubled]")
    
    eval(generated_code)
    
    calculator = MultiDeps.from({ "base" => 3 })
    
    expect(calculator[:doubled]).to eq(6)    # 3 * 2
    expect(calculator[:squared]).to eq(36)   # 6 * 6  
    expect(calculator[:final]).to eq(45)     # 36 + 6 + 3
  end

  it "handles dependencies in array contexts" do
    schema = <<~KUMI
      schema do
        input do
          array :items do
            integer :value
          end
        end

        value :doubled_values, input.items.value * 2
        value :items_with_doubled, input.items.value + doubled_values
      end
    KUMI

    pack = pack_for(schema)
    generator = Kumi::Codegen::RubyV3::Generator.new(pack, module_name: "ArrayDeps")
    
    generated_code = generator.render
    
    # Should reference array declaration with proper indexing
    expect(generated_code).to include("self[:doubled_values]")
    
    eval(generated_code)
    
    calculator = ArrayDeps.from({ "items" => [{"value" => 10}, {"value" => 20}] })
    
    expect(calculator[:doubled_values]).to eq([20, 40])
    expect(calculator[:items_with_doubled]).to eq([30, 60])  # [10+20, 20+40]
  end
end