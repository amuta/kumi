#!/usr/bin/env ruby

require_relative '../lib/kumi'
require_relative 'ir_generator'
require_relative 'ir_compiler'

module SimpleSchema
  extend Kumi::Schema

  schema skip_compiler: true do
    input do
      float :price
    end

    value :price_with_markup, input.price * 1.2
  end
end

puts "=== AST ==="
ast = SimpleSchema.__syntax_tree__
puts ast.inspect

puts "\n=== Analysis ==="
analyzer_result = Kumi::Analyzer.analyze!(ast)

puts "Analysis result fields:"
puts "- definitions: #{analyzer_result.definitions&.keys}"  
puts "- topo_order: #{analyzer_result.topo_order}"
puts "- decl_types: #{analyzer_result.decl_types}"

puts "\n=== IR Generation ==="
ir_generator = Kumi::Core::IRGenerator.new(SimpleSchema, analyzer_result)
ir = ir_generator.generate

puts "Generated IR:"
puts "- accessors: #{ir[:accessors].keys}"
puts "- instructions: #{ir[:instructions].map { |i| "#{i[:name]} (#{i[:operation_type]})" }}"

puts "\n=== Full IR Structure ==="
puts "Accessors:"
ir[:accessors].each { |k, v| puts "  #{k}: #{v}" }

puts "\nInstructions:"
ir[:instructions].each { |instruction| puts "  #{instruction}" }

puts "\nDependencies:"
puts "  #{ir[:dependencies]}"

puts "\n=== IR Compilation ==="
begin
  ir_compiler = Kumi::Core::IRCompiler.new(ir)
  compiled_schema = ir_compiler.compile
  
  puts "Compiled successfully!"
  
  # Test execution
  test_data = { price: 100.0 }
  result = compiled_schema.bindings[:price_with_markup].call(test_data)
  puts "Test result: price_with_markup(100.0) = #{result}"
  
rescue => e
  puts "Compilation failed: #{e.message}"
  puts e.backtrace.first(3)
end