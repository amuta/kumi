#!/usr/bin/env ruby

require_relative "../lib/kumi"
require_relative "tac_ir_generator"
require 'pp'

puts "=" * 60
puts "TAC SYSTEM - COMPLEX EXPRESSION ANALYSIS"
puts "=" * 60

module TACOnlyTestSchema
  extend Kumi::Schema
  
  schema skip_compiler: true do
    input do
      array :items do
        float :value
        float :weight
      end
      float :multiplier
    end
    
    # Complex nested operation that only TAC can handle
    value :complex, (input.items.value * 2.0) + input.multiplier
  end
end

ast = TACOnlyTestSchema.__syntax_tree__
analysis_result = Kumi::Analyzer.analyze!(ast)

puts "\nBroadcast detector metadata:"
detector_metadata = analysis_result.state[:detector_metadata] || {}
detector_metadata.each do |name, metadata|
  puts "#{name}:"
  puts "  operation_type: #{metadata[:operation_type]}"
  puts "  depth: #{metadata[:depth]}"
  puts "  operands: #{metadata[:operands]&.length || 0}"
end

puts "\n" + "=" * 40
puts "TAC IR GENERATION"
puts "=" * 40

tac_generator = Kumi::Core::TACIRGenerator.new(ast, analysis_result)
tac_ir = tac_generator.generate

File.open('/home/muta/repos/kumi/compiler_refactor/tac_complex_output.txt', 'w') do |f|
  f.puts "TAC SYSTEM - COMPLEX EXPRESSION"
  f.puts "=" * 50
  f.puts
  f.puts "Broadcast Detector Metadata:"
  detector_metadata.each do |name, metadata|
    f.puts "#{name}:"
    f.puts "  operation_type: #{metadata[:operation_type]}"
    f.puts "  depth: #{metadata[:depth]}"
    f.puts "  access_mode: #{metadata[:access_mode]}"
    f.puts "  dimension_mode: #{metadata[:dimension_mode]}"
    f.puts "  operands count: #{metadata[:operands]&.length || 0}"
    if metadata[:operands]
      metadata[:operands].each_with_index do |op, i|
        f.puts "    [#{i}] type: #{op[:type]}, source: #{op[:source][:kind]}"
      end
    end
  end
  
  f.puts "\nFull TAC IR Structure:"
  f.puts PP.pp(tac_ir, "")
  f.puts
  f.puts "Instructions breakdown:"
  tac_ir[:instructions].each_with_index do |instruction, i|
    f.puts "\n[#{i}] #{instruction[:name]}:"
    f.puts "  operation_type: #{instruction[:operation_type]}"
    f.puts "  temp: #{instruction[:temp]}"
    f.puts "  compilation type: #{instruction[:compilation][:type]}"
    f.puts "  function: #{instruction[:compilation][:function]}"
    f.puts "  operands:"
    instruction[:compilation][:operands].each_with_index do |operand, j|
      f.puts "    [#{j}] type: #{operand[:type]}"
      f.puts "        details: #{operand.inspect}"
    end
  end
end

puts "File written: tac_complex_output.txt"
puts "This shows how TAC handles complex expressions with broadcast metadata"