#!/usr/bin/env ruby
# frozen_string_literal: true

# Enhanced debug script for analyzing Kumi's analyzer state
# Usage: ruby scripts/debug_analyzer_state.rb

require_relative '../lib/kumi'
require_relative '../spec/support/analyzer_state_helper'

include AnalyzerStateHelper
include Kumi::Support

puts "=== ENHANCED ANALYZER STATE DEBUGGING ==="

# Complex schema for dimensional analysis testing
state = analyze_up_to(:join_plans) do
  input do
    array :companies do
      string :name
      hash :hr_info do
        string :policy
        array :employees do
          integer :hours
          string :level
          hash :personal_info do
            string :email
            array :projects do
              string :title
              integer :priority
            end
          end
        end
      end
    end
  end

  value :employee_hours, input.companies.hr_info.employees.hours
  value :total_hours_per_company, fn(:sum, input.companies.hr_info.employees.hours)
  value :project_priorities, input.companies.hr_info.employees.personal_info.projects.priority
  value :avg_priority_per_employee, fn(:mean, input.companies.hr_info.employees.personal_info.projects.priority)
end

puts "🚀 ONE-COMMAND COMPLETE DIAGNOSTIC:"
StateDumper.dump_complete_diagnostic(state)

puts "\n" + "="*60
puts "ADDITIONAL ANALYSIS EXAMPLES:"
puts "="*60

puts "\n🔍 Quick issue detection:"
StateDumper.dump_issue_summary(state)

puts "\n🔎 Find specific paths:"
StateDumper.find_nodes_by_path(state, "employees.hours")

puts "\n📊 Find reduction operations:"
StateDumper.find_nodes_by_function(state, :sum)

puts "\n🔗 Dependency analysis:"
sum_nodes = state[:node_index].select { |oid, meta|
  node = meta[:expression_node] || meta[:node] 
  node&.respond_to?(:fn_name) && node.fn_name == :sum
}

if sum_nodes.any?
  target_oid = sum_nodes.keys.first
  puts "Deep trace for sum operation (OID #{target_oid}):"
  StateDumper.dump_dependency_chain(state, target_oid)
end

puts "\n✅ ENHANCED DEBUGGING COMPLETE"
puts "Use StateDumper methods for targeted analysis of specific issues"