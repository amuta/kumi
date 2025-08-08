# frozen_string_literal: true

require_relative "../../lib/kumi/core/compiler/access_planner"
require_relative "../../lib/kumi/core/compiler/access_builder"

RSpec.describe "AccessPlanner + AccessBuilder Integration" do
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
    plans = Kumi::Core::Compiler::AccessPlanner.plan(input_metadata)

    # Step 2: Build the actual lambdas
    accessors = Kumi::Core::Compiler::AccessBuilder.build(plans)

    # Step 3: Test with real data
    test_data = {
      "regions" => [
        { "tax_rate" => 0.2 },
        { "tax_rate" => 0.15 }
      ]
    }

    # Test structure accessor
    regions_accessor = accessors["regions:ravel"]
    expect(regions_accessor.call(test_data)).to eq([
                                                     { "tax_rate" => 0.2 },
                                                     { "tax_rate" => 0.15 }
                                                   ])

    # Test element-wise yielder accessor
    tax_rate_accessor = accessors["regions.tax_rate:each_indexed"]
    tax_rate_accessor.call(test_data).each do |v, idx|
      expect(v).to eq(test_data["regions"][idx[0]]["tax_rate"]) # idx[0] because idx is a ND-array index
    end
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

    plans = Kumi::Core::Compiler::AccessPlanner.plan(input_metadata)
    accessors = Kumi::Core::Compiler::AccessBuilder.build(plans)

    test_data = {
      "regions" => [
        { "offices" => [{ "revenue" => 100.0 }, { "revenue" => 200.0 }] },
        { "offices" => [{ "revenue" => 150.0 }] }
      ]
    }

    # Test nested array access
    revenue_accessor = accessors["regions.offices.revenue:materialize"]
    expect(revenue_accessor.call(test_data)).to eq([[100.0, 200.0], [150.0]])
  end

  it "handles mixed symbol/string keys" do
    input_metadata = { regions: { type: :array, children: { tax_rate: { type: :float } } } }
    plans = Kumi::Core::Compiler::AccessPlanner.plan(input_metadata)
    accessors = Kumi::Core::Compiler::AccessBuilder.build(plans)

    test_data = { regions: [{ "tax_rate" => 0.2 }, { tax_rate: 0.15 }] }
    expect(accessors["regions.tax_rate:materialize"].call(test_data)).to eq([0.2, 0.15])
  end

  it "returns nils on missing leafs when key is missing" do
    input_metadata = { regions: { type: :array, children: { tax_rate: { type: :float } } } }
    plans = Kumi::Core::Compiler::AccessPlanner.plan(input_metadata, { on_missing: :nil })
    accessors = Kumi::Core::Compiler::AccessBuilder.build(plans)

    test_data = { "regions" => [{}, { "tax_rate" => 0.15 }] }

    expect(accessors["regions.tax_rate:ravel"].call(test_data)).to eq([nil, 0.15])
  end

  it "supports vector mode flattening - not yet implemented" do
    input_metadata = {
      regions: { type: :array, children: {
        offices: { type: :array, children: { revenue: { type: :float } } }
      } }
    }
    plans = Kumi::Core::Compiler::AccessPlanner.plan(input_metadata) # should include :ravel plans
    accessors = Kumi::Core::Compiler::AccessBuilder.build(plans)

    test_data = { "regions" => [
      { "offices" => [{ "revenue" => 100.0 }, { "revenue" => 200.0 }] },
      { "offices" => [{ "revenue" => 150.0 }] }
    ] }

    expect(accessors["regions.offices.revenue:ravel"].call(test_data)).to eq([100.0, 200.0, 150.0])
  end

  it "exposes yield access with index paths - not yet implemented" do
    input_metadata = {
      regions: { type: :array, children: {
        offices: { type: :array, children: { revenue: { type: :float } } }
      } }
    }
    plans = Kumi::Core::Compiler::AccessPlanner.plan(input_metadata)
    accessors = Kumi::Core::Compiler::AccessBuilder.build(plans)

    test_data = { "regions" => [{ "offices" => [{ "revenue" => 100.0 }, { "revenue" => 200.0 }] }] }
    seen = []
    accessors["regions.offices.revenue:each_indexed"].call(test_data) { |v, idx| seen << [v, idx] }

    expect(seen).to eq([[100.0, [0, 0]], [200.0, [0, 1]]])
  end

  it "handles empty arrays at any level" do
    input_metadata = { regions: { type: :array, children: { offices: { type: :array, children: { revenue: { type: :float } } } } } }
    accessors = Kumi::Core::Compiler::AccessBuilder.build(Kumi::Core::Compiler::AccessPlanner.plan(input_metadata))
    expect(accessors["regions.offices.revenue:materialize"].call({ "regions" => [] })).to eq([])
    expect(accessors["regions.offices.revenue:materialize"].call({ "regions" => [{ "offices" => [] }] })).to eq([[]])
  end
end
