#!/usr/bin/env ruby

require_relative "ir_test_helper"
require_relative "tests/array_broadcasting_clean"
require_relative "tac_ir_generator"
require 'pp'

puts "=" * 80
puts "IR STRUCTURE COMPARISON"
puts "=" * 80

# Test with array broadcasting schema
module SimpleTestSchema
  extend Kumi::Schema
  
  schema skip_compiler: true do
    input do
      array :items do
        float :value
        float :weight
      end
      float :multiplier
    end
    
    # Simple element-wise operation (both systems can handle this)
    value :doubled, input.items.value * 2.0
  end
end

ast = SimpleTestSchema.__syntax_tree__
analysis_result = Kumi::Analyzer.analyze!(ast)

puts "\n" + "=" * 40
puts "REGULAR IR GENERATOR OUTPUT"
puts "=" * 40

regular_ir_gen = Kumi::Core::IRGenerator.new(ast, analysis_result)
regular_ir = regular_ir_gen.generate

File.open('/home/muta/repos/kumi/compiler_refactor/regular_ir_output.txt', 'w') do |f|
  f.puts "REGULAR IR GENERATOR OUTPUT"
  f.puts "=" * 50
  f.puts
  f.puts "Full IR Structure:"
  f.puts PP.pp(regular_ir, "")
  f.puts
  f.puts "Instructions breakdown:"
  regular_ir[:instructions].each_with_index do |instruction, i|
    f.puts "\n[#{i}] #{instruction[:name]}:"
    f.puts "  operation_type: #{instruction[:operation_type]}"
    f.puts "  compilation type: #{instruction[:compilation][:type]}"
    f.puts "  compilation structure:"
    f.puts PP.pp(instruction[:compilation], "", 4).split("\n").map { |line| "    #{line}" }.join("\n")
  end
end

puts "\n" + "=" * 40
puts "TAC IR GENERATOR OUTPUT"  
puts "=" * 40

tac_generator = Kumi::Core::TACIRGenerator.new(ast, analysis_result)
tac_ir = tac_generator.generate

File.open('/home/muta/repos/kumi/compiler_refactor/tac_ir_output.txt', 'w') do |f|
  f.puts "TAC IR GENERATOR OUTPUT"
  f.puts "=" * 50
  f.puts
  f.puts "Full IR Structure:"
  f.puts PP.pp(tac_ir, "")
  f.puts
  f.puts "Instructions breakdown:"
  tac_ir[:instructions].each_with_index do |instruction, i|
    f.puts "\n[#{i}] #{instruction[:name]}:"
    f.puts "  operation_type: #{instruction[:operation_type]}"
    f.puts "  compilation type: #{instruction[:compilation][:type] if instruction[:compilation]}"
    f.puts "  temp: #{instruction[:temp]}"
    f.puts "  compilation structure:"
    f.puts PP.pp(instruction[:compilation], "", 4).split("\n").map { |line| "    #{line}" }.join("\n") if instruction[:compilation]
  end
end

puts "\nFiles written:"
puts "- regular_ir_output.txt"
puts "- tac_ir_output.txt"
puts "\nCompare the structures to see how broadcast metadata should flow through TAC!"