#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
require_relative 'spec/spec_helper'

include PackTestHelper

schema = <<~KUMI
  schema do
    input do
      array :numbers do
        integer :value
      end
    end
    
    value :total, fn(:sum, input.numbers.value)
  end
KUMI

pack = pack_for(schema)
generator = Kumi::Codegen::RubyV3::Generator.new(pack, module_name: "OrderingTest")

generated_code = generator.render
puts "=== GENERATED CODE ==="
puts generated_code
puts "======================"

# Analyze the structure
lines = generated_code.split("\n")
while_line_idx = lines.find_index { |line| line.include?("while i0 < arr0.length") }
end_line_idx = lines.find_index(while_line_idx) { |line| line.strip == "end" }

puts "\n=== ANALYSIS ==="
puts "While line at index: #{while_line_idx}"
puts "End line at index: #{end_line_idx}"

if while_line_idx && end_line_idx
  loop_body_lines = lines[(while_line_idx + 1)...end_line_idx]
  puts "Loop body lines:"
  loop_body_lines.each_with_index do |line, i|
    puts "  #{while_line_idx + 1 + i}: #{line}"
  end
  
  value_access_line = loop_body_lines.find { |line| line.include?('a0["value"]') }
  acc_add_line = loop_body_lines.find { |line| line.include?("acc_") && line.include?("+=") }
  
  puts "\nValue access line: #{value_access_line.inspect}"
  puts "Acc add line: #{acc_add_line.inspect}"
else
  puts "Could not find while loop structure"
end