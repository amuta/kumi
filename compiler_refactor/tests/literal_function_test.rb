#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../../lib/kumi'

module LiteralFunctionTest
  extend Kumi::Schema

  schema skip_compiler: true do
    input do
      # Empty input block
    end
    
    # Force literals with literal() wrapper to prevent parse-time evaluation
    value :x, literal(10) + literal(20) * literal(2)
  end
end

puts "=== Testing Forced Literal Functions ==="
puts "Expression: literal(10) + literal(20) * literal(2)"
puts

ast = LiteralFunctionTest.__syntax_tree__
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

if x_declaration.expression.is_a?(Kumi::Syntax::CallExpression)
  puts "Outer function: #{x_declaration.expression.fn_name}"
  puts "Args: #{x_declaration.expression.args.map(&:class)}"
  x_declaration.expression.args.each_with_index do |arg, i|
    puts "  Arg[#{i}]: #{arg.class}"
    if arg.is_a?(Kumi::Syntax::CallExpression)
      puts "    Inner function: #{arg.fn_name}"
      puts "    Inner args: #{arg.args.map { |a| "#{a.class}(#{a.respond_to?(:value) ? a.value : a.inspect})" }}"
    end
  end
end