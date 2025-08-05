#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"

coverage_file = "coverage/.resultset.json"

unless File.exist?(coverage_file)
  puts "❌ No coverage data found. Run tests first:"
  puts "   COVERAGE=true bundle exec rspec"
  exit 1
end

data = JSON.parse(File.read(coverage_file))
coverage = data.values.first["coverage"]

broadcast_file = coverage.find { |file, _| file.include?("broadcast_detector.rb") }

if broadcast_file
  file_path, line_data = broadcast_file
  lines = line_data["lines"]
  
  puts "🔍 BroadcastDetector Coverage Analysis:"
  puts "File: #{File.basename(file_path)}"
  
  total_lines = lines.count { |hits| !hits.nil? }
  covered_lines = lines.count { |hits| hits && hits > 0 }
  coverage_percent = (covered_lines.to_f / total_lines * 100).round(1)
  
  puts "Coverage: #{coverage_percent}% (#{covered_lines}/#{total_lines} lines)"
  
  # Find uncovered method definitions
  file_content = File.read(file_path)
  uncovered_methods = []
  covered_methods = []
  
  file_content.lines.each_with_index do |line, i|
    if line.match?(/^\s*def\s+(\w+)/)
      method_name = line.match(/^\s*def\s+(\w+)/)[1]
      line_hits = lines[i]
      
      if line_hits.nil?
        # Line not tracked
      elsif line_hits == 0
        uncovered_methods << "#{method_name} (line #{i+1})"
      else
        covered_methods << "#{method_name} (line #{i+1})"
      end
    end
  end
  
  puts "\n📊 Method Coverage Summary:"
  puts "  Total methods: #{covered_methods.length + uncovered_methods.length}"
  puts "  Covered methods: #{covered_methods.length}"
  puts "  Uncovered methods: #{uncovered_methods.length}"
  
  if uncovered_methods.any?
    puts "\n🚨 Uncovered methods (potential dead code):"
    uncovered_methods.each { |m| puts "    - #{m}" }
  end
  
  if covered_methods.any?
    puts "\n✅ Covered methods:"
    covered_methods.each { |m| puts "    - #{m}" }
  end
else
  puts "❌ BroadcastDetector file not found in coverage data"
end