#!/usr/bin/env ruby

require_relative "../ir_test_helper"

module SimpleScalar
  extend Kumi::Schema

  schema skip_compiler: true do
    input do
      integer :x
      integer :y
    end

    value :sum, input.x + input.y
    value :product, input.x * input.y
    value :is_positive, input.x > 0
  end
end

test_data = { x: 5, y: 3 }

expected = {
  sum: 8,
  product: 15,
  is_positive: true
}

puts "Testing SimpleScalar Schema"
puts "=" * 50

results = IRTestHelper.run_test(SimpleScalar, test_data, expected, debug: false)

puts "\nResults:"
results.each do |key, value|
  status = value == expected[key] ? "✓" : "✗"
  puts "#{status} #{key}: #{value}"
end
