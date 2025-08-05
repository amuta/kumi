#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"

coverage_file = "coverage/.resultset.json"
target_file = "cascade_executor_builder.rb"

unless File.exist?(coverage_file)
  puts "❌ No coverage data found. Run tests first"
  exit 1
end

data = JSON.parse(File.read(coverage_file))
coverage = data.values.first["coverage"]

file_entry = coverage.find { |file, _| file.include?(target_file) }

if file_entry
  file_path, line_data = file_entry
  lines = line_data["lines"]
  
  puts "🔍 CascadeExecutorBuilder Method Coverage:"
  puts "=" * 50
  
  file_content = File.read(file_path)
  methods = []
  
  file_content.lines.each_with_index do |line, i|
    if line.match?(/^\s*def\s+/)
      method_match = line.match(/^\s*def\s+(self\.)?(\w+)/)
      if method_match
        method_name = method_match[2]
        is_class_method = !method_match[1].nil?
        line_hits = lines[i]
        
        status = if line_hits.nil?
                   "⚪ NOT TRACKED"
                 elsif line_hits == 0
                   "🚨 UNCOVERED"
                 else
                   "✅ COVERED (#{line_hits} hits)"
                 end
        
        prefix = is_class_method ? "self." : ""
        methods << {
          name: "#{prefix}#{method_name}",
          line: i + 1,
          hits: line_hits,
          status: status
        }
      end
    end
  end
  
  methods.each do |method|
    printf "  %-25s (line %3d) %s\n", method[:name], method[:line], method[:status]
  end
  
  uncovered = methods.select { |m| m[:hits] == 0 }
  covered = methods.select { |m| m[:hits] && m[:hits] > 0 }
  
  puts "\n📊 Summary:"
  puts "  Total methods: #{methods.length}"
  puts "  Covered: #{covered.length}"
  puts "  Uncovered: #{uncovered.length}"
  
  if uncovered.any?
    puts "\n🚨 Uncovered methods (potential dead code):"
    uncovered.each { |m| puts "    #{m[:name]} (line #{m[:line]})" }
  end
else
  puts "❌ #{target_file} not found in coverage data"
end