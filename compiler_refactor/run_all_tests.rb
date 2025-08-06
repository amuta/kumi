#!/usr/bin/env ruby

require 'pathname'

# Find all test files
test_dir = Pathname.new(__dir__)
test_files = [
  "simple_scalar_test.rb",
  "cascade_test_clean.rb", 
  "array_broadcasting_clean.rb"
]

puts "=" * 70
puts "Running IR Compiler Tests"
puts "=" * 70

test_files.each do |test_file|
  puts "\n" + "▶" * 35
  puts "Running: #{test_file}"
  puts "▶" * 35
  
  path = test_dir.join(test_file)
  if path.exist?
    system("ruby", path.to_s)
  else
    puts "❌ File not found: #{path}"
  end
  
  puts "\n"
end

puts "=" * 70
puts "All tests completed"
puts "=" * 70