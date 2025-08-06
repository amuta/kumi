#!/usr/bin/env ruby

require_relative "../ir_test_helper"

module BroadcastChainTest
  extend Kumi::Schema

  schema skip_compiler: true do
    input do
      array :items do
        float :value
      end
    end

    # Simple declared operation
    value :doubled, input.items.value * 2.0

    # Reference to declaration
    value :doubled_plus_one, doubled + 1.0

    # Inline nested expression
    value :inline_nested, (input.items.value * 2.0) + 1.0
  end
end

puts "=== Current Broadcast Detector Output ==="

# Let's examine what the broadcast detector produces
begin
  # Get the analysis directly to see broadcast detector metadata
  syntax_tree = BroadcastChainTest.__syntax_tree__
  analysis_result = Kumi::Analyzer.analyze!(syntax_tree)

  detector_metadata = analysis_result.state[:detector_metadata]

  puts "\nBroadcast detector metadata:"
  %i[doubled doubled_plus_one inline_nested].each do |name|
    meta = detector_metadata[name]
    puts "\n#{name}:"
    puts "  operation_type: #{meta[:operation_type]}"

    if meta[:operands]
      puts "  operands:"
      meta[:operands].each_with_index do |op, i|
        puts "    [#{i}] type: #{op[:type]}, source: #{op[:source]}"
      end
    end

    puts "  strategy: #{meta[:strategy]}" if meta[:strategy]
  end

  puts "\n=== IR Generator Output ==="

  # Now see what the IR generator produces
  ir_generator = Kumi::Core::IRGenerator.new(syntax_tree, analysis_result)
  ir = ir_generator.generate

  puts "\nIR instructions:"
  ir[:instructions].each do |instruction|
    puts "\n#{instruction[:name]}:"
    puts "  operation_type: #{instruction[:operation_type]}"
    puts "  compilation: #{instruction[:compilation][:type]}"

    next unless instruction[:compilation][:operands]

    puts "  compilation operands:"
    instruction[:compilation][:operands].each_with_index do |op, i|
      puts "    [#{i}] #{op}"
    end
  end

  puts "\n=== Compilation Test ==="
  result = IRTestHelper.compile_schema(BroadcastChainTest)

  test_data = { items: [{ value: 10.0 }, { value: 20.0 }] }
  runner = result[:compiled_schema]

  %i[doubled doubled_plus_one inline_nested].each do |name|
    value = runner.bindings[name].call(test_data)
    puts "#{name}: #{value.inspect}"
  rescue StandardError => e
    puts "#{name}: ERROR - #{e.message}"
  end
rescue StandardError => e
  puts "Error: #{e.message}"
  puts "  at: #{e.backtrace.first}"
end
