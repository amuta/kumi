#!/usr/bin/env ruby

require_relative "../ir_test_helper"
require "json"

module IRAnalysisTest
  extend Kumi::Schema

  schema skip_compiler: true do
    input do
      array :items do
        float :value
        float :weight
      end
      float :multiplier
    end

    # Different chain patterns
    value :doubled_values, input.items.value * 2.0
    value :doubled_plus_multiplier, doubled_values + input.multiplier
    value :inline_chain, (input.items.weight * 2.0) + input.multiplier
    value :combined, doubled_values + input.items.weight
  end
end

# Generate IR and write to file
result = IRTestHelper.compile_schema(IRAnalysisTest, debug: false)
ir = result[:ir]

# Write IR to JSON file for analysis
File.write("ir_output.json", JSON.pretty_generate(ir))

puts "IR written to ir_output.json"

# Also write a human-readable version
File.open("ir_analysis.txt", "w") do |f|
  f.puts "=== IR ANALYSIS ==="
  f.puts

  f.puts "ACCESSORS:"
  ir[:accessors].each do |key, value|
    f.puts "  #{key}: #{value.class}"
  end
  f.puts

  f.puts "INSTRUCTIONS:"
  ir[:instructions].each_with_index do |instruction, i|
    f.puts "#{i + 1}. #{instruction[:name]} (#{instruction[:operation_type]})"
    f.puts "   data_type: #{instruction[:data_type]}"
    f.puts "   compilation: #{instruction[:compilation][:type]}"

    if instruction[:compilation][:operands]
      f.puts "   operands:"
      instruction[:compilation][:operands].each_with_index do |operand, j|
        f.puts "     [#{j}] #{operand[:type]}"
        case operand[:type]
        when :input_element_reference
          f.puts "         path: #{operand[:path]}"
          f.puts "         accessor: #{operand[:accessor]}"
        when :declaration_reference
          f.puts "         name: #{operand[:name]}"
        when :literal
          f.puts "         value: #{operand[:value]}"
        when :computed_result
          f.puts "         operation_type: #{operand[:operation_metadata][:operation_type]}"
          f.puts "         strategy: #{operand[:operation_metadata][:strategy]}"
        end
      end
    end
    f.puts
  end

  f.puts "DEPENDENCIES:"
  ir[:dependencies].each do |name, deps|
    f.puts "  #{name}: #{deps}"
  end
end

puts "Human-readable IR written to ir_analysis.txt"

# Test execution
test_data = {
  items: [
    { value: 10.0, weight: 1.0 },
    { value: 20.0, weight: 2.0 },
    { value: 30.0, weight: 3.0 }
  ],
  multiplier: 5.0
}

runner = result[:compiled_schema]

puts
puts "=== EXECUTION TEST ==="
%i[doubled_values doubled_plus_multiplier inline_chain combined].each do |name|
  actual = runner.bindings[name].call(test_data)
  puts "#{name}: #{actual.inspect}"
rescue StandardError => e
  puts "#{name}: ERROR - #{e.message}"
end
