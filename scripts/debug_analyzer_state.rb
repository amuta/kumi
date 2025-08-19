#!/usr/bin/env ruby
# frozen_string_literal: true

# Debug script for analyzing Kumi's analyzer state
# Usage: ruby scripts/debug_analyzer_state.rb

require_relative '../lib/kumi'
require_relative '../spec/support/analyzer_state_helper'
require_relative '../lib/kumi/support/state_dumper'

include AnalyzerStateHelper
include Kumi::Support::StateDumper

# Example: Debug dimensional analysis issues
puts "=== Dimensional Analysis Debug Example ==="

state = analyze_up_to(:join_reduce_plans) do
  input do
    array :companies do
      string :name
      hash :hr_info do
        string :policy
        array :employees do
          integer :hours
          hash :personal_info do
            array :projects do
              string :title
              integer :priority
            end
          end
        end
      end
    end
  end

  # Values to debug
  value :employee_hours, input.companies.hr_info.employees.hours
  value :total_hours, fn(:sum, input.companies.hr_info.employees.hours)
  value :avg_priority, fn(:mean, input.companies.hr_info.employees.personal_info.projects.priority)
end

puts "\n1. Dump specific state keys:"
dump_state(state, keys: [:decl_shapes, :input_metadata])

puts "\n2. Show only CallExpression nodes:"
dump_calls_only(state)

puts "\n3. Custom filter - show input references:"
dump_node_index(state) do |metadata|
  metadata[:type] == "InputElementReference"
end

puts "\n4. Check for dimensional issues:"
bad_scopes = []
(state[:decl_shapes] || {}).each do |name, shape|
  # Look for hash navigation in scopes (should be array-only)
  if shape[:scope].any? { |seg| [:hr_info, :personal_info].include?(seg) }
    bad_scopes << [name, shape[:scope]]
  end
end

if bad_scopes.any?
  puts "❌ Found hash segments in scopes:"
  bad_scopes.each { |name, scope| puts "  #{name}: #{scope.inspect}" }
else
  puts "✅ All scopes contain only array boundaries"
end