# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Wrapped mode exposes internal VM structures" do
  module WrappedBaseSchema
    extend Kumi::Schema

    build_syntax_tree do
      input do
        array :items do
          float   :price
          integer :quantity
          string  :category
        end
        string :customer_tier
        float  :shipping_threshold
      end

      # Vectorized core
      value :subtotals, input.items.price * input.items.quantity
      trait :electronics, input.items.category == "electronics"
      trait :bulk_item,   input.items.quantity >= 5
      trait :premium_customer, input.customer_tier == "premium"

      trait :premium_electronics, premium_customer & electronics
      trait :stacked_discount,    premium_electronics & bulk_item

      value :discounted_prices do
        on stacked_discount,     input.items.price * 0.75
        on premium_electronics,  input.items.price * 0.85
        on bulk_item,            input.items.price * 0.90
        base                     input.items.price
      end

      value :final_subtotals, discounted_prices * input.items.quantity

      # Reductions + scalars
      value :subtotal, fn(:sum, final_subtotals)
      trait :over_shipping_threshold, subtotal >= input.shipping_threshold
      value :total_savings, fn(:sum, subtotals) - subtotal
      value :shipping do
        on over_shipping_threshold, 0.0
        base 9.99
      end
      value :total, subtotal + shipping
    end
  end

  let(:syntax_tree)    { WrappedBaseSchema.__syntax_tree__ }
  let(:analysis_state) { Kumi::Analyzer.analyze!(syntax_tree).state }
  let(:program)        { Kumi::Runtime::Program.from_analysis(analysis_state) }

  let(:input_premium) do
    {
      "items" => [
        { "price" => 100.0, "quantity" => 2, "category" => "electronics" },
        { "price" => 200.0, "quantity" => 2, "category" => "electronics" }
      ],
      "customer_tier" => "premium",
      "shipping_threshold" => 50.0
    }
  end

  it "returns scalar result under the public name" do
    out = program.read(input_premium)

    expect(out.subtotals).to eq([200.0, 400.0])
    expect(out.discounted_prices).to eq([85.0, 170.0])
    expect(out.total_savings).to eq(90.0)
    expect(out.subtotal).to eq(510.0)
    expect(out.shipping).to eq(0.0)
    expect(out.total).to eq(510.0)
  end

  it "applies stacked discount (premium + electronics + bulk) and free shipping" do
    input = {
      "items" => [
        { "price" => 100.0, "quantity" => 5, "category" => "electronics" }, # stacked → 25% off
        { "price" => 200.0, "quantity" => 5, "category" => "electronics" }  # stacked → 25% off
      ],
      "customer_tier" => "premium",
      "shipping_threshold" => 50.0
    }

    r = program.read(input)

    expect(r.electronics).to eq([true, true])
    expect(r.subtotals).to eq([500.0, 1000.0])              # pre-discount subtotals
    expect(r.discounted_prices).to eq([75.0, 150.0])        # 25% off
    expect(r.final_subtotals).to eq([375.0, 750.0])         # discounted * quantity
    expect(r.total_savings).to eq(1500.0 - 1125.0)          # = 375.0
    expect(r.subtotal).to eq(1125.0)
    expect(r.shipping).to eq(0.0)                           # free shipping
    expect(r.total).to eq(1125.0)
  end

  it "applies premium electronics only (no bulk) and charges shipping" do
    input = {
      "items" => [
        { "price" => 100.0, "quantity" => 2, "category" => "electronics" }, # premium electronics → 15% off
        { "price" => 200.0, "quantity" => 1, "category" => "electronics" }  # premium electronics → 15% off
      ],
      "customer_tier" => "premium",
      "shipping_threshold" => 400.0
    }

    r = program.read(input)

    expect(r.electronics).to eq([true, true])
    expect(r.subtotals).to eq([200.0, 200.0])
    expect(r.discounted_prices).to eq([85.0, 170.0])        # 15% off
    expect(r.final_subtotals).to eq([170.0, 170.0])
    expect(r.subtotal).to eq(340.0)
    expect(r.shipping).to eq(9.99)                          # under threshold
    expect(r.total).to be_within(1e-6).of(349.99)
  end

  it "applies bulk-only discount for non-electronics" do
    input = {
      "items" => [
        { "price" => 50.0, "quantity" => 5,  "category" => "books" }, # bulk → 10% off
        { "price" => 20.0, "quantity" => 10, "category" => "grocery" } # bulk → 10% off
      ],
      "customer_tier" => "basic",
      "shipping_threshold" => 100.0
    }

    r = program.read(input)

    expect(r.electronics).to eq([false, false])
    expect(r.subtotals).to eq([250.0, 200.0])
    expect(r.discounted_prices).to eq([45.0, 18.0])
    expect(r.final_subtotals).to eq([225.0, 180.0])
    expect(r.total_savings).to eq((250.0 + 200.0) - (225.0 + 180.0)) # 45.0
    expect(r.subtotal).to eq(405.0)
    expect(r.shipping).to eq(0.0)                                    # over threshold
    expect(r.total).to eq(405.0)
  end

  it "handles a mixed cart (premium electronics, bulk non-electronics, and base)" do
    input = {
      "items" => [
        { "price" => 100.0, "quantity" => 2, "category" => "electronics" }, # 15% off
        { "price" => 50.0,  "quantity" => 5, "category" => "books"       }, # 10% off
        { "price" => 10.0,  "quantity" => 1, "category" => "grocery"     }  # base
      ],
      "customer_tier" => "premium",
      "shipping_threshold" => 300.0
    }

    r = program.read(input)

    expect(r.electronics).to eq([true, false, false])
    expect(r.subtotals).to eq([200.0, 250.0, 10.0])

    # per-item cascade:
    expect(r.discounted_prices).to eq([85.0, 45.0, 10.0]) # [15% off, 10% off, base]
    expect(r.final_subtotals).to eq([170.0, 225.0, 10.0])

    expect(r.subtotal).to eq(405.0)
    expect(r.total_savings).to eq((200.0 + 250.0 + 10.0) - 405.0) # 55.0
    expect(r.shipping).to eq(0.0)
    expect(r.total).to eq(405.0)
  end

  it "falls back to base prices when neither premium nor bulk applies" do
    input = {
      "items" => [
        { "price" => 12.0, "quantity" => 1, "category" => "books"   },
        { "price" => 20.0, "quantity" => 2, "category" => "grocery" }
      ],
      "customer_tier" => "basic",
      "shipping_threshold" => 999.0
    }

    r = program.read(input)

    expect(r.electronics).to eq([false, false])
    expect(r.discounted_prices).to eq([12.0, 20.0]) # base path in cascade
    expect(r.final_subtotals).to eq([12.0, 40.0])
    expect(r.subtotal).to eq(52.0)
    expect(r.shipping).to eq(9.99)
    expect(r.total).to be_within(1e-6).of(61.99)
    expect(r.total_savings).to eq(0.0)
  end

  it "handles an empty cart (sum=0) and charges shipping" do
    input = {
      "items" => [],
      "customer_tier" => "basic",
      "shipping_threshold" => 50.0
    }

    r = program.read(input)

    expect(r.subtotals).to eq([])
    expect(r.discounted_prices).to eq([])
    expect(r.final_subtotals).to eq([])
    expect(r.subtotal).to eq(0.0)
    expect(r.shipping).to eq(9.99)
    expect(r.total).to be_within(1e-6).of(9.99)
  end
end
