#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../../lib/kumi'

module InputMathTest
  extend Kumi::Schema

  schema skip_compiler: true do
    input do
      integer :a
      integer :b
    end
    
    # Math with input references - should create function calls
    value :x, input.a + input.b * 10
  end
end

puts "=== Testing Math with Input References ==="
puts "Expression: input.a + input.b * 10"
puts

ast = InputMathTest.__syntax_tree__
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
    puts "  Arg[#{i}]: #{arg.class} - #{arg.inspect}"
    if arg.is_a?(Kumi::Syntax::CallExpression)
      puts "    Inner function: #{arg.fn_name}"
      puts "    Inner args: #{arg.args.map(&:class)}"
    end
  end
end