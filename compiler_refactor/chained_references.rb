#!/usr/bin/env ruby

require_relative '../lib/kumi'
require_relative 'ir_generator'
require_relative 'ir_compiler'

module ChainedReferences
  extend Kumi::Schema

  schema skip_compiler: true do
    input do
      float :base_price
      integer :quantity
    end

    # Chain of value references
    value :subtotal, input.base_price * input.quantity
    value :tax_amount, subtotal * 0.1
    value :total, subtotal + tax_amount

    # Traits that reference values
    trait :expensive_subtotal, subtotal > 500.0
    trait :high_tax, tax_amount > 50.0
    trait :expensive_total, total > 600.0

    # Values that use traits in cascade conditions
    value :discount_rate do
      on expensive_total, 0.95    # 5% off expensive orders
      on expensive_subtotal, 0.98 # 2% off expensive subtotals
      on high_tax, 0.99           # 1% off high tax orders
      base 1.0                    # no discount
    end

    value :final_total, total * discount_rate
  end
end

puts "=== Analysis ==="
analyzer_result = Kumi::Analyzer.analyze!(ChainedReferences.__syntax_tree__)

puts "Topo order: #{analyzer_result.topo_order}"
puts "Dependencies:"
analyzer_result.state[:dependencies].each do |name, deps|
  dep_names = deps.map(&:to)
  puts "  #{name} -> #{dep_names}"
end

puts "\n=== IR Generation ==="
ir_generator = Kumi::Core::IRGenerator.new(ChainedReferences, analyzer_result)
ir = ir_generator.generate

puts "Instructions order:"
ir[:instructions].each_with_index do |instruction, i|
  puts "  #{i+1}. #{instruction[:name]} (#{instruction[:operation_type]})"
end

puts "\n=== IR Compilation ==="
begin
  ir_compiler = Kumi::Core::IRCompiler.new(ir)
  compiled_schema = ir_compiler.compile
  puts "Compiled successfully!"

  # Test chained references
  test_data = { base_price: 100.0, quantity: 6 }
  
  subtotal = compiled_schema.bindings[:subtotal].call(test_data)
  tax_amount = compiled_schema.bindings[:tax_amount].call(test_data)
  total = compiled_schema.bindings[:total].call(test_data)
  expensive_subtotal = compiled_schema.bindings[:expensive_subtotal].call(test_data)
  high_tax = compiled_schema.bindings[:high_tax].call(test_data)
  expensive_total = compiled_schema.bindings[:expensive_total].call(test_data)
  discount_rate = compiled_schema.bindings[:discount_rate].call(test_data)
  final_total = compiled_schema.bindings[:final_total].call(test_data)

  puts "\n=== Test Results ==="
  puts "subtotal: #{subtotal}"
  puts "tax_amount: #{tax_amount}"
  puts "total: #{total}"
  puts "expensive_subtotal: #{expensive_subtotal}"
  puts "high_tax: #{high_tax}"
  puts "expensive_total: #{expensive_total}"
  puts "discount_rate: #{discount_rate}"
  puts "final_total: #{final_total}"

rescue => e
  puts "Error: #{e.message}"
  puts e.backtrace.first(5)
end