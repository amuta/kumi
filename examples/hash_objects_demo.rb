# frozen_string_literal: true

# Hash Objects Demo - Demonstrates Kumi's structured input syntax
# This example shows how to use hash objects for organizing related input fields

require_relative "../lib/kumi"

module HashObjectsDemo
  extend Kumi::Schema

  schema do
    input do
      # Employee information as hash object
      hash :employee do
        string :name
        integer :age, domain: 18..65
        float :base_salary, domain: 30_000.0..200_000.0
        boolean :is_manager
        integer :years_experience, domain: 0..40
      end
      
      # Company configuration as hash object
      hash :company_config do
        string :name
        float :bonus_percentage, domain: 0.0..0.50
        float :manager_multiplier, domain: 1.0..2.0
        integer :current_year, domain: 2020..2030
      end
      
      # Benefits configuration as hash object
      hash :benefits do
        boolean :health_insurance
        boolean :dental_coverage
        float :retirement_match, domain: 0.0..0.10
        integer :vacation_days, domain: 10..30
      end
    end

    # Traits using hash object access
    trait :is_senior, input.employee.years_experience >= 5
    trait :eligible_for_bonus, is_senior & input.employee.is_manager
    trait :has_full_benefits, input.benefits.health_insurance & input.benefits.dental_coverage

    # Salary calculations using structured data
    value :base_annual_salary, input.employee.base_salary
    
    value :bonus_amount do
      on eligible_for_bonus, base_annual_salary * input.company_config.bonus_percentage
      base 0.0
    end
    
    trait :is_manager_trait, input.employee.is_manager == true
    
    value :manager_adjustment do
      on is_manager_trait, input.company_config.manager_multiplier
      base 1.0
    end
    
    value :total_compensation, (base_annual_salary * manager_adjustment) + bonus_amount
    
    # Benefits calculations
    value :retirement_contribution, total_compensation * input.benefits.retirement_match
    
    value :benefits_package_value do
      on has_full_benefits, 5_000.0 + input.benefits.vacation_days * 150.0
      base input.benefits.vacation_days * 100.0
    end
    
    # Final totals
    value :total_package_value, total_compensation + retirement_contribution + benefits_package_value
    
    # Summary calculations
    value :years_to_retirement, 65 - input.employee.age
  end
end

# Example usage
if __FILE__ == $0
  puts "Hash Objects Demo - Employee Compensation Calculator"
  puts "=" * 55

  # Sample data demonstrating hash objects structure
  employee_data = {
    employee: {
      name: "Alice Johnson",
      age: 32,
      base_salary: 85_000.0,
      is_manager: true,
      years_experience: 8
    },
    company_config: {
      name: "Tech Solutions Inc",
      bonus_percentage: 0.15,
      manager_multiplier: 1.25,
      current_year: 2024
    },
    benefits: {
      health_insurance: true,
      dental_coverage: true,
      retirement_match: 0.06,
      vacation_days: 25
    }
  }

  # Calculate compensation
  result = HashObjectsDemo.from(employee_data)
  
  def format_currency(amount)
    "$#{amount.round(0).to_s.gsub(/\B(?=(\d{3})+(?!\d))/, ',')}"
  end
  
  puts "\nEmployee Information:"
  puts "- Name: #{employee_data[:employee][:name]}"
  puts "- Age: #{employee_data[:employee][:age]}"
  puts "- Experience: #{employee_data[:employee][:years_experience]} years"
  puts "- Manager: #{employee_data[:employee][:is_manager] ? 'Yes' : 'No'}"
  
  puts "\nCompany: #{employee_data[:company_config][:name]}"
  puts "- Bonus Rate: #{(employee_data[:company_config][:bonus_percentage] * 100).round(1)}%"
  puts "- Manager Multiplier: #{employee_data[:company_config][:manager_multiplier]}x"
  
  puts "\nBenefits:"
  puts "- Health Insurance: #{employee_data[:benefits][:health_insurance] ? 'Yes' : 'No'}"
  puts "- Dental Coverage: #{employee_data[:benefits][:dental_coverage] ? 'Yes' : 'No'}"
  puts "- Retirement Match: #{(employee_data[:benefits][:retirement_match] * 100).round(1)}%"
  puts "- Vacation Days: #{employee_data[:benefits][:vacation_days]}"

  puts "\nCompensation Breakdown:"
  puts "- Base Salary: #{format_currency(result[:base_annual_salary])}"
  puts "- Manager Adjustment: #{result[:manager_adjustment]}x"
  puts "- Bonus: #{format_currency(result[:bonus_amount])}"
  puts "- Total Compensation: #{format_currency(result[:total_compensation])}"
  puts "- Retirement Contribution: #{format_currency(result[:retirement_contribution])}"
  puts "- Benefits Package Value: #{format_currency(result[:benefits_package_value])}"
  
  puts "\nTotal Package: #{format_currency(result[:total_package_value])}"
  puts "Years to Retirement: #{result[:years_to_retirement]}"
end