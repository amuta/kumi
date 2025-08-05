#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"

coverage_file = "coverage/.resultset.json"

unless File.exist?(coverage_file)
  puts "❌ No coverage data found. Run tests first"
  exit 1
end

data = JSON.parse(File.read(coverage_file))
coverage = data.values.first["coverage"]

broadcasting_files = [
  "cascade_executor_builder.rb",
  "vectorized_function_builder.rb", 
  "nested_structure_utils.rb",
  "broadcast_detector.rb"
]

puts "🔍 Broadcasting Files Coverage:"
puts "=" * 60

broadcasting_files.each do |filename|
  file_entry = coverage.find { |file, _| file.include?(filename) }
  
  if file_entry
    file_path, line_data = file_entry
    lines = line_data["lines"]
    
    total_lines = lines.count { |hits| !hits.nil? }
    covered_lines = lines.count { |hits| hits && hits > 0 }
    coverage_percent = total_lines > 0 ? (covered_lines.to_f / total_lines * 100).round(1) : 0
    
    status = if coverage_percent == 0
               "🚨 DEAD"
             elsif coverage_percent < 20
               "🔴 LOW"  
             elsif coverage_percent < 50
               "🟡 MEDIUM"
             else
               "✅ GOOD"
             end
    
    printf "%-35s %s %6.1f%% (%d/%d lines)\n", filename, status, coverage_percent, covered_lines, total_lines
  else
    printf "%-35s ❌ NOT FOUND\n", filename
  end
end