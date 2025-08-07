#!/usr/bin/env ruby

require_relative "../ir_test_helper"

module ChainedFunctionsTest
  extend Kumi::Schema

  schema skip_compiler: true do
    input do
      array :items do
        float :value
      end
    end

    value :chained_functions, (input.items.value * 2.0) + 1.0
  end
end

# Test data
test_data = {
  items: [
    { value: 10.0 },
    { value: 20.0 },
    { value: 30.0 }
  ]
}

expected = {
  chained_functions: [21.0, 41.0, 61.0]  # (10*2)+1, (20*2)+1, (30*2)+1
}

puts "=== Testing Chained Functions: (input.items.value * 2.0) + 1.0 ==="
puts "Expected: #{expected[:chained_functions]}"
puts

results = IRTestHelper.run_test(ChainedFunctionsTest, test_data, expected, debug: true)