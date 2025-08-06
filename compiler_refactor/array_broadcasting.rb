#!/usr/bin/env ruby

require_relative "../lib/kumi"
require_relative "ir_generator"
require_relative "ir_compiler"

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

puts "=== AST Structure ==="
ast = ArrayBroadcasting.__syntax_tree__
puts "Expression class: #{ast.attributes.first.expression.class}"
puts "First arg class: #{ast.attributes.first.expression.args.first.class}"
puts "First arg: #{ast.attributes.first.expression.args.first.inspect}"
puts "Second arg class: #{ast.attributes.first.expression.args.last.class}"
puts "Second arg: #{ast.attributes.first.expression.args.last.inspect}"

puts "\n=== Analysis ==="
analyzer_result = Kumi::Analyzer.analyze!(ArrayBroadcasting.__syntax_tree__)

puts "Topo order: #{analyzer_result.topo_order}"
puts "Types: #{analyzer_result.decl_types}"
puts "Should be: {:item_subtotals => {:array => :float}}"

puts "\n=== Input Metadata Debug ==="
input_metadata = analyzer_result.state[:inputs]
puts "Input metadata keys: #{input_metadata&.keys}"
input_metadata&.each do |key, meta|
  puts "#{key}: #{meta}"
end

puts "\n=== Detector Metadata (Broadcasting Info) ==="
detector_metadata = analyzer_result.state[:detector_metadata] || {}
detector_metadata.each do |name, meta|
  puts "#{name}: #{meta}"
end

puts "\n=== IR Generation ==="
begin
  ir_generator = Kumi::Core::IRGenerator.new(ArrayBroadcasting, analyzer_result)
  ir = ir_generator.generate

  puts "Instructions order:"
  ir[:instructions].each_with_index do |instruction, i|
    puts "  #{i + 1}. #{instruction[:name]} (#{instruction[:operation_type]}, #{instruction[:data_type]})"
  end

  puts "\n=== Full IR Structure ==="
  puts "Accessors:"
  ir[:accessors].each { |k, v| puts "  #{k}: #{v}" }

  puts "\nInstructions:"
  ir[:instructions].each { |instruction| puts "  #{instruction}" }

  puts "\n=== IR Compilation ==="
  ir_compiler = Kumi::Core::IRCompiler.new(ir)
  compiled_schema = ir_compiler.compile
  puts "Compiled successfully!"

  puts "\n=== Test Execution ==="
  test_data = {
    line_items: [
      { price: 100.0, quantity: 2, coupons: [5.0, 10.0] },
      { price: 50.0, quantity: 3 }  # Missing coupons field - should fail
    ]
  }

  puts "\n=== Test Basic Accessors ==="
  element_accessor = ir[:accessors]["line_items.coupons:element"]
  puts "Element accessor found: #{!element_accessor.nil?}"
  
  if element_accessor
    begin
      element_result = element_accessor.call(test_data)
      puts "Element accessor result: #{element_result}"
      puts "Expected: [[5.0, 10.0], [2.0]]"
    rescue => e
      puts "Element accessor error: #{e.message}"
      puts e.backtrace[0..2]
    end
  end

  puts "\n=== Test Full Computation ==="
  subtotals_result = compiled_schema.bindings[:item_subtotals].call(test_data)
  coupon_discounts_result = compiled_schema.bindings[:total_coupon_discounts].call(test_data)
  discounted_subtotals_result = compiled_schema.bindings[:discounted_subtotals].call(test_data)
  
  puts "item_subtotals: #{subtotals_result}"
  puts "Expected: [200.0, 150.0]"
  
  puts "total_coupon_discounts: #{coupon_discounts_result}"
  puts "Expected: [15.0, 2.0] (sum of coupons per item)"
  
  puts "discounted_subtotals: #{discounted_subtotals_result}"  
  puts "Expected: [185.0, 148.0] (subtotals minus coupon discounts)"
  
  # puts "total_coupon_discounts: #{coupon_discounts_result}"
  # puts "Expected: [15.0, 0.0] (sum of coupons per item)"
  
  # puts "discounted_subtotals: #{discounted_subtotals_result}"  
  # puts "Expected: [185.0, 150.0] (subtotals minus coupon discounts)"
rescue StandardError => e
  puts "Error: #{e.message}"
  puts "This shows us what needs to be implemented!"
  puts e.backtrace.first(5)
end
