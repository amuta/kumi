#!/usr/bin/env ruby

require_relative '../lib/kumi'
require_relative 'ir_generator'
require_relative 'ir_compiler'

module DependenciesTest
  extend Kumi::Schema

  schema skip_compiler: true do
    input do
      float :base_price
      float :tax_rate
    end

    value :price_with_tax, input.base_price * input.tax_rate
    value :final_price, price_with_tax + 5.0
    trait :expensive, final_price > 100.0
  end
end

puts "=== Analysis ==="
analyzer_result = Kumi::Analyzer.analyze!(DependenciesTest.__syntax_tree__)

puts "Topo order: #{analyzer_result.topo_order}"
puts "Types: #{analyzer_result.decl_types}"

puts "\n=== Full Analyzer State ==="
state = analyzer_result.state
puts "State keys: #{state.keys}"
state.each do |key, value|
  puts "#{key}:"
  case value
  when Hash
    puts "  #{value.keys} (#{value.class})"
  when Array  
    puts "  #{value.length} items (#{value.class})"
  else
    puts "  #{value.inspect}"
  end
end

puts "\n=== IR Generation ==="
ir_generator = Kumi::Core::IRGenerator.new(DependenciesTest, analyzer_result)
ir = ir_generator.generate

puts "Instructions order:"
ir[:instructions].each_with_index do |instruction, i|
  puts "  #{i+1}. #{instruction[:name]} (#{instruction[:operation_type]}, #{instruction[:data_type]})"
end

puts "\nDependencies:"
ir[:dependencies].each do |name, deps|
  dep_names = deps.map(&:to)
  puts "  #{name} depends on: #{dep_names}"
end

puts "\n=== IR Compilation ==="
begin
  ir_compiler = Kumi::Core::IRCompiler.new(ir)
  compiled_schema = ir_compiler.compile
  
  puts "Compiled successfully!"
  
  # Test execution
  test_data = { base_price: 90.0, tax_rate: 1.15 }
  
  price_with_tax = compiled_schema.bindings[:price_with_tax].call(test_data)
  final_price = compiled_schema.bindings[:final_price].call(test_data)
  expensive = compiled_schema.bindings[:expensive].call(test_data)
  
  puts "Results:"
  puts "  price_with_tax: #{price_with_tax}"
  puts "  final_price: #{final_price}" 
  puts "  expensive: #{expensive}"
  
rescue => e
  puts "Error: #{e.message}"
  puts e.backtrace.first(3)
end