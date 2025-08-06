#!/usr/bin/env ruby

require_relative "../ir_test_helper"

puts "=== Simple nested_call test ==="

# Test the exact difference between declaration vs nested call
module SimpleNestedTest
  extend Kumi::Schema

  schema skip_compiler: true do
    input do
      array :items do
        float :value
      end
    end

    # This creates a declaration
    value :plus_one, input.items.value + 1.0

    # Case 1: Using declaration reference - should be {:kind=>:declaration}
    value :from_declaration, plus_one + 1.0

    # Case 2: Using inline call expression - should be {:kind=>:nested_call}
    value :from_inline, (input.items.value + 1.0) + 1.0
  end
end

puts "\n--- Examining AST Structure ---"
ast = SimpleNestedTest.__syntax_tree__

# Find the relevant declarations
from_declaration = ast.attributes.find { |a| a.name == :from_declaration }
from_inline = ast.attributes.find { |a| a.name == :from_inline }

puts "from_declaration expression: #{from_declaration.expression.class}"
puts "  -> #{from_declaration.expression.inspect}"

puts "\nfrom_inline expression: #{from_inline.expression.class}"
puts "  -> #{from_inline.expression.inspect}"

# Let's look at the operands in detail
if from_declaration.expression.respond_to?(:args)
  puts "\nfrom_declaration args:"
  from_declaration.expression.args.each_with_index do |arg, i|
    puts "  arg[#{i}]: #{arg.class} -> #{arg.inspect}"
  end
end

if from_inline.expression.respond_to?(:args)
  puts "\nfrom_inline args:"
  from_inline.expression.args.each_with_index do |arg, i|
    puts "  arg[#{i}]: #{arg.class} -> #{arg.inspect}"
  end
end

puts "\n--- Now trying compilation ---"
begin
  result = IRTestHelper.compile_schema(SimpleNestedTest, debug: false)
  puts "✓ Both patterns compiled successfully"
rescue StandardError => e
  puts "✗ Compilation failed: #{e.message}"
end
