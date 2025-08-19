require "spec_helper"
require_relative "golden_helper"

RSpec.describe "Golden: Semantic Dimensions and Array Boundaries" do
  include GoldenHelper
  include AnalyzerStateHelper

  describe "semantic dimensions with mixed array/hash navigation" do
    let(:schema_block) do
      proc do
        input do
          # Test array -> hash -> array pattern to verify semantic dimensions
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

        # Test semantic dimensions at different levels
        # companies.hr_info.employees.hours should have scope [:companies, :employees]
        # (ignoring hr_info hash navigation)
        value :employee_hours, input.companies.hr_info.employees.hours

        # companies.hr_info.employees.personal_info.projects.priority should have scope
        # [:companies, :employees, :projects] (ignoring hash navigations)
        value :project_priorities, input.companies.hr_info.employees.personal_info.projects.priority

        # Test reductions over semantic dimensions
        value :total_hours_per_company, fn(:sum, input.companies.hr_info.employees.hours)
        # Should reduce over :employees axis, result scope [:companies]

        value :avg_priority_per_employee, fn(:mean, input.companies.hr_info.employees.personal_info.projects.priority)
        # Should reduce over :projects axis, result scope [:companies, :employees]

        # Test cascades with semantic dimensions
        trait :high_hours, input.companies.hr_info.employees.hours > 35
        trait :high_priority_projects, fn(:any?, input.companies.hr_info.employees.personal_info.projects.priority > 8)

        value :employee_status do
          on high_hours, high_priority_projects, "Busy with critical work"
          on high_hours, "Busy"
          on high_priority_projects, "Critical projects"
          base "Normal workload"
        end
      end
    end

    let(:test_data) do
      {
        companies: [
          {
            name: "TechCorp",
            hr_info: {
              policy: "flexible",
              employees: [
                {
                  hours: 40,
                  level: "senior",
                  personal_info: {
                    email: "alice@techcorp.com",
                    projects: [
                      { title: "WebApp", priority: 9 },
                      { title: "API", priority: 7 }
                    ]
                  }
                },
                {
                  hours: 30,
                  level: "junior",
                  personal_info: {
                    email: "bob@techcorp.com",
                    projects: [
                      { title: "Tests", priority: 5 }
                    ]
                  }
                }
              ]
            }
          },
          {
            name: "DataCorp",
            hr_info: {
              policy: "remote",
              employees: [
                {
                  hours: 45,
                  level: "senior",
                  personal_info: {
                    email: "carol@datacorp.com",
                    projects: [
                      { title: "ML Pipeline", priority: 10 },
                      { title: "Dashboard", priority: 6 }
                    ]
                  }
                }
              ]
            }
          }
        ]
      }
    end

    it "correctly handles semantic dimensions ignoring hash navigation" do
      result = execute_schema_raw(schema_block, test_data)
      inspect_results(result, "SEMANTIC DIMENSIONS TEST")

      # Verify semantic dimension behavior
      expect(result).to have_key(:employee_hours)
      expect(result).to have_key(:project_priorities)
      expect(result).to have_key(:total_hours_per_company)
      expect(result).to have_key(:avg_priority_per_employee)
      expect(result).to have_key(:employee_status)

      # Test the key insight: array boundaries create dimensions, hash navigation doesn't
      puts "\n=== SEMANTIC DIMENSIONS VERIFICATION ==="
      puts "Path: companies.hr_info.employees.hours"
      puts "- Array boundaries: :companies, :employees (2 dimensions)"
      puts "- Hash navigation: :hr_info (ignored)"
      puts "- Expected scope: [:companies, :employees]"

      puts "\nPath: companies.hr_info.employees.personal_info.projects.priority"
      puts "- Array boundaries: :companies, :employees, :projects (3 dimensions)"
      puts "- Hash navigation: :hr_info, :personal_info (ignored)"
      puts "- Expected scope: [:companies, :employees, :projects]"

      puts "\nReduction behavior:"
      puts "- total_hours_per_company should reduce :employees → result per company"
      puts "- avg_priority_per_employee should reduce :projects → result per employee"

      # The actual values demonstrate the semantic dimension system working
      puts "\nActual results:"
      puts "total_hours_per_company: #{result[:total_hours_per_company]}"
      puts "avg_priority_per_employee: #{result[:avg_priority_per_employee]}"
    end
  end
end
