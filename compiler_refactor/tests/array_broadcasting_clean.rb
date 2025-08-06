#!/usr/bin/env ruby

require_relative "../ir_test_helper"

module ArrayBroadcasting
  extend Kumi::Schema

  schema skip_compiler: true do
    input do
      array :line_items do
        float :price
        integer :quantity
        array :coupons do
          element :float, :discount_value
        end
      end
      float :tax_rate
    end

    # Array broadcasting - should be vectorized operations
    value :item_subtotals, input.line_items.price * input.line_items.quantity

    # Calculate total coupon discounts per item (sum of coupons within each item)
    # This should be vectorized: map sum over each item's coupon array
    value :total_coupon_discounts, fn(:sum, input.line_items.coupons)

    # Apply coupon discounts to subtotals
    value :discounted_subtotals, item_subtotals - total_coupon_discounts
  end
end

# Test with proper data
test_data = {
  line_items: [
    { price: 100.0, quantity: 2, coupons: [5.0, 10.0] },
    { price: 50.0, quantity: 3, coupons: [] }
  ]
}

expected = {
  item_subtotals: [200.0, 150.0],
  total_coupon_discounts: [15.0, 0],
  discounted_subtotals: [185.0, 150.0]
}

puts "Testing ArrayBroadcasting Schema"
puts "=" * 50

results = IRTestHelper.run_test(ArrayBroadcasting, test_data, expected, debug: false)

puts "\nResults:"
results.each do |key, value|
  status = value == expected[key] ? "✓" : "✗"
  puts "#{status} #{key}: #{value}"
end
