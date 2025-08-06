# frozen_string_literal: true

require_relative "../../lib/kumi/core/compiler/accessor_planner"
require_relative "../../lib/kumi/core/compiler/accessor_builder"

RSpec.describe "AccessorPlanner + AccessorBuilder Integration" do
  it "works together to create working accessors for simple array" do
    input_metadata = {
      regions: {
        type: :array,
        children: {
          tax_rate: { type: :float }
        }
      }
    }

    # Step 1: Plan the accessors
    plans = Kumi::Core::Compiler::AccessorPlanner.plan(input_metadata)
    
    # Step 2: Build the actual lambdas
    accessors = Kumi::Core::Compiler::AccessorBuilder.build(plans)
    
    # Step 3: Test with real data
    test_data = {
      "regions" => [
        { "tax_rate" => 0.2 },
        { "tax_rate" => 0.15 }
      ]
    }

    # Test structure accessor
    regions_accessor = accessors["regions:structure"]
    expect(regions_accessor.call(test_data)).to eq([
      { "tax_rate" => 0.2 },
      { "tax_rate" => 0.15 }
    ])
    
    # Test element accessor 
    tax_rate_accessor = accessors["regions.tax_rate:element"]
    expect(tax_rate_accessor.call(test_data)).to eq([0.2, 0.15])
  end

  it "works with vector access mode for flattening" do
    input_metadata = {
      matrix: {
        type: :array,
        access_mode: :vector,
        children: {
          cell: { type: :integer }
        }
      }
    }

    plans = Kumi::Core::Compiler::AccessorPlanner.plan(input_metadata)
    accessors = Kumi::Core::Compiler::AccessorBuilder.build(plans)
    
    test_data = {
      "matrix" => [
        { "cell" => [1, 2, 3] },
        { "cell" => [4, 5] },
        { "cell" => [6, 7, 8, 9] }
      ]
    }

    # Test flattened accessor
    flattened_accessor = accessors["matrix.cell:flattened"]
    expect(flattened_accessor.call(test_data)).to eq([1, 2, 3, 4, 5, 6, 7, 8, 9])
  end

  it "works with nested arrays" do
    input_metadata = {
      regions: {
        type: :array,
        children: {
          offices: {
            type: :array,
            children: {
              revenue: { type: :float }
            }
          }
        }
      }
    }

    plans = Kumi::Core::Compiler::AccessorPlanner.plan(input_metadata)
    accessors = Kumi::Core::Compiler::AccessorBuilder.build(plans)
    
    test_data = {
      "regions" => [
        { "offices" => [{ "revenue" => 100.0 }, { "revenue" => 200.0 }] },
        { "offices" => [{ "revenue" => 150.0 }] }
      ]
    }

    # Test nested array access
    revenue_accessor = accessors["regions.offices.revenue:element"]
    expect(revenue_accessor.call(test_data)).to eq([[100.0, 200.0], [150.0]])
  end
end