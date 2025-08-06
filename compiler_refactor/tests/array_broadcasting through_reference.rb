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
      end
      float :tax_rate
    end

    # Array broadcasting - should be vectorized operations through reference
    value :item_quantity, input.line_items.quantity
    value :item_price, input.line_items.price
    value :item_subtotals, item_price * item_quantity

    value :total_subtotal, fn(:sum, item_subtotals)
  end
end

module SimpleArray
  extend Kumi::Schema

  schema skip_compiler: true do
    input do
      array :line_items do
        float :price
        integer :quantity
      end
    end

    # Just array broadcasting
    value :item_subtotals, input.line_items.price * input.line_items.quantity
  end
end

puts "=== AST Structure ==="
ast = ArrayBroadcasting.__syntax_tree__
ast.attributes.each_with_index do |attr, i|
  puts "#{i+1}. #{attr.name}: #{attr.expression.class} - #{attr.expression.inspect}"
end

# Skip the problematic analysis for now and test just the simpler case
puts "\n=== Analysis (simple case only) ==="
analyzer_result = Kumi::Analyzer.analyze!(SimpleArray.__syntax_tree__)

puts "Topo order: #{analyzer_result.topo_order}"
puts "Types: #{analyzer_result.decl_types}"
puts "Should be: {:item_subtotals => {:array => :float}}"

puts "\n=== Detector Metadata (Broadcasting Info) ==="
detector_metadata = analyzer_result.state[:detector_metadata] || {}
detector_metadata.each do |name, meta|
  puts "#{name}: #{meta}"
end

puts "\n=== IR Generation ==="
begin
  ir_generator = Kumi::Core::IRGenerator.new(SimpleArray, analyzer_result)
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
rescue StandardError => e
  puts "Error: #{e.message}"
  puts "This shows us what needs to be implemented!"
  puts e.backtrace.first(3)
end
