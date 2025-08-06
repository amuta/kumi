#!/usr/bin/env ruby

require_relative '../lib/kumi'
require_relative 'ir_generator'
require_relative 'ir_compiler'

module CascadeTest
  extend Kumi::Schema

  schema skip_compiler: true do
    input do
      float :price
      string :category
    end

    trait :luxury, input.category == "luxury"
    trait :budget, input.category == "budget"

    value :discount_rate do
      on luxury, 0.9
      on budget, 0.8
      base 1.0
    end

    value :final_price, input.price * discount_rate
  end
end

puts "=== Analysis ==="
analyzer_result = Kumi::Analyzer.analyze!(CascadeTest.__syntax_tree__)

puts "Topo order: #{analyzer_result.topo_order}"
puts "Types: #{analyzer_result.decl_types}"

puts "\n=== Detector Metadata ==="
detector_metadata = analyzer_result.state[:detector_metadata] || {}
detector_metadata.each do |name, meta|
  puts "#{name}: #{meta}"
end

puts "\n=== IR Generation ==="
begin
  ir_generator = Kumi::Core::IRGenerator.new(CascadeTest, analyzer_result)
  ir = ir_generator.generate

  puts "Instructions order:"
  ir[:instructions].each_with_index do |instruction, i|
    puts "  #{i+1}. #{instruction[:name]} (#{instruction[:operation_type]}, #{instruction[:data_type]})"
  end

  puts "\n=== IR Compilation ==="
  ir_compiler = Kumi::Core::IRCompiler.new(ir)
  compiled_schema = ir_compiler.compile
  puts "Compiled successfully!"

  puts "\n=== Testing Cascade Logic ==="
  test_cases = [
    { price: 100.0, category: "luxury" },
    { price: 100.0, category: "budget" }, 
    { price: 100.0, category: "regular" }
  ]

  test_cases.each do |test_data|
    luxury = compiled_schema.bindings[:luxury].call(test_data)
    budget = compiled_schema.bindings[:budget].call(test_data)
    discount_rate = compiled_schema.bindings[:discount_rate].call(test_data)
    final_price = compiled_schema.bindings[:final_price].call(test_data)
    
    puts "#{test_data[:category]}: luxury=#{luxury}, budget=#{budget}, rate=#{discount_rate}, final=#{final_price}"
  end

rescue => e
  puts "Error: #{e.message}"
  puts "This shows us what we need to implement next!"
  puts e.backtrace.first(3)
end