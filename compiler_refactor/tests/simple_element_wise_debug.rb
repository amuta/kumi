#!/usr/bin/env ruby

require_relative "../ir_test_helper"

module SimpleElementWiseDebug
  extend Kumi::Schema

  schema skip_compiler: true do
    input do
      array :items do
        float :value
      end
    end

    # The most basic element-wise case
    value :basic_multiply, input.items.value * 2.0
  end
end

puts "=" * 60
puts "BASIC ELEMENT-WISE DEBUG"
puts "=" * 60

test_data = { items: [{ value: 10.0 }, { value: 20.0 }] }

begin
  result = IRTestHelper.compile_schema(SimpleElementWiseDebug, debug: false)
  
  puts "\nFull IR Instruction for basic_multiply:"
  basic_instr = result[:ir][:instructions].find { |i| i[:name] == :basic_multiply }
  require 'pp'
  puts PP.pp(basic_instr, "", 2).split("\n").map { |line| "  #{line}" }.join("\n")
  
  puts "\nAccessor test:"
  puts "Testing the items.value:element accessor directly..."
  accessor = result[:ir][:accessors]["items.value:element"]
  if accessor
    accessor_result = accessor.call(test_data)
    puts "  items.value:element accessor result: #{accessor_result.inspect} (#{accessor_result.class})"
  else
    puts "  items.value:element accessor not found!"
  end
  
  puts "\nCompilation attempt:"
  runner = result[:compiled_schema]
  basic_result = runner.bindings[:basic_multiply].call(test_data)
  puts "  basic_multiply result: #{basic_result.inspect}"
  
rescue => e
  puts "Error: #{e.message}"
  puts "  at: #{e.backtrace.first}"
end