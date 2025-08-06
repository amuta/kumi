#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../../lib/kumi'

module NestedFunctionTest
  extend Kumi::Schema
  
  schema skip_compiler: true do
    input do
      integer :a
      integer :b  
    end
    
    # Nested function calls that can't be pre-evaluated
    value :complex_calc, fn(:add, fn(:multiply, input.a, 5), fn(:multiply, input.b, 3))
  end
end

puts "=== Testing Nested Function Calls ==="
puts "Expression: fn(:add, fn(:multiply, input.a, 5), fn(:multiply, input.b, 3))"
puts

ast = NestedFunctionTest.__syntax_tree__
analysis_result = Kumi::Analyzer.analyze!(ast)

detector_metadata = analysis_result.state[:detector_metadata] || {}
puts "Detector metadata: #{detector_metadata.inspect}"
puts

if detector_metadata[:complex_calc]
  puts "Metadata for :complex_calc:"
  detector_metadata[:complex_calc].each do |key, value|
    puts "  #{key}: #{value.inspect}"
  end
end

puts "\nAST structure:"
calc_declaration = ast.attributes.find { |attr| attr.name == :complex_calc }
puts "Declaration expression: #{calc_declaration.expression.class}"

if calc_declaration.expression.is_a?(Kumi::Syntax::CallExpression)
  puts "Outer function: #{calc_declaration.expression.fn_name}"
  puts "Number of args: #{calc_declaration.expression.args.length}"
  calc_declaration.expression.args.each_with_index do |arg, i|
    puts "  Arg[#{i}]: #{arg.class}"
    if arg.is_a?(Kumi::Syntax::CallExpression)
      puts "    Function: #{arg.fn_name}"
      puts "    Args: #{arg.args.map(&:class)}"
    end
  end
end