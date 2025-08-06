#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../../lib/kumi'

extend Kumi::Schema

schema skip_compiler: true do
  input do
    # Empty input block
  end
  
  # Simple math that should get parsed as function calls
  value :x, 2 + 2 * 10
end

puts "=== Testing Simple Math Expression ==="
puts "Expression: 2 + 2 * 10"
puts

ast = self.__syntax_tree__
analysis_result = Kumi::Analyzer.analyze!(ast)

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

if x_declaration.expression.is_a?(Kumi::Syntax::CallExpression)
  puts "Function name: #{x_declaration.expression.fn_name}"
  puts "Args: #{x_declaration.expression.args.map(&:class)}"
  x_declaration.expression.args.each_with_index do |arg, i|
    puts "  Arg[#{i}]: #{arg.inspect}"
  end
end