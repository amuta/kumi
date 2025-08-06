#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../../lib/kumi'

module SimpleNestedTest
  extend Kumi::Schema
  
  schema skip_compiler: true do
    input do
      # Empty input block
    end
    
    # Complex scalar expression with no arrays
    value :x, 2 + 2**10
  end
end

puts "=== Testing Complex Scalar Expression ==="
puts "Expression: 2 + 2**10"
puts

ast = SimpleNestedTest.__syntax_tree__
analysis_result = Kumi::Analyzer.analyze!(ast)

puts "Analyzer state keys: #{analysis_result.state.keys}"
puts

detector_metadata = analysis_result.state[:detector_metadata] || {}
puts "Detector metadata: #{detector_metadata.inspect}"
puts

if detector_metadata[:x]
  puts "Metadata for :x:"
  detector_metadata[:x].each do |key, value|
    puts "  #{key}: #{value.inspect}"
  end
end

puts "\nAST structure:"
x_declaration = ast.attributes.find { |attr| attr.name == :x }
puts "Declaration expression: #{x_declaration.expression.class}"
puts "Expression inspect: #{x_declaration.expression.inspect}"

if x_declaration.expression.respond_to?(:fn_name)
  puts "Function name: #{x_declaration.expression.fn_name}"
  puts "Args: #{x_declaration.expression.args.map(&:class)}"
end