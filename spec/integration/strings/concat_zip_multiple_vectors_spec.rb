# frozen_string_literal: true
require "spec_helper"

RSpec.describe "Concat — zip multiple vectors & nils" do
  let(:schema_mod) do
    Module.new do
      extend Kumi::Schema
      schema do
        input do
          array :items do
            string :name
            float  :price
            string :currency
          end
        end
        value :line, fn(:concat, input.items.name, " : ", input.items.price, " ", input.items.currency)
      end
    end
  end

  it "zips vectors over the same axis" do
    s = schema_mod.from(items: [
      {name:"Item1", price:10.5, currency:"USD"},
      {name:"Item2", price:15.0, currency:"USD"}
    ])
    expect(s.line).to eq(["Item1 : 10.5 USD", "Item2 : 15.0 USD"])
  end

  it "propagates nils element-wise" do
    s = schema_mod.from(items: [
      {name:"Item1", price:nil,  currency:"USD"},
      {name:"Item2", price:15.0, currency:"USD"}
    ])
    expect(s.line).to eq([nil, "Item2 : 15.0 USD"])
  end
end