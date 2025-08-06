# frozen_string_literal: true

require_relative "../../../../lib/kumi/core/compiler/accessor_planner"

RSpec.describe Kumi::Core::Compiler::AccessorPlanner do
  it "creates structure and element plans for simple array field" do
    input_metadata = {
      items: {
        type: :array,
        children: {
          price: { type: :float }
        }
      }
    }

    plans = described_class.plan(input_metadata)

    expect(plans).to have_key("items.price")
    expect(plans["items.price"][:structure][:type]).to eq(:structure)
    expect(plans["items.price"][:element][:type]).to eq(:element)
  end

  it "creates plans for scalar fields" do
    input_metadata = {
      name: { type: :string }
    }

    plans = described_class.plan(input_metadata)

    expect(plans).to have_key("name")
    expect(plans["name"][:structure][:path]).to eq([:name])
    expect(plans["name"][:element][:path]).to eq([:name])
  end

  it "creates flattened plans for vector access mode" do
    input_metadata = {
      matrix: {
        type: :array,
        access_mode: :vector,
        children: {
          cell: { type: :integer }
        }
      }
    }

    plans = described_class.plan(input_metadata)

    expect(plans["matrix.cell"]).to have_key(:flattened)
    expect(plans["matrix.cell"][:flattened][:type]).to eq(:flattened)
  end
end