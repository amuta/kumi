# frozen_string_literal: true

require 'spec_helper'

RSpec.describe "Element :any Hash Access" do
  describe "element :any as alternative to hash objects" do
    it "handles basic hash data with element :any syntax" do
      schema = Module.new do
        extend Kumi::Schema
        
        schema do
          input do
            array :users do
              element :any, :profile
            end
          end
          
          value :profiles, input.users.profile
          value :user_names, fn(:fetch, input.users.profile, "name")
          value :user_ages, fn(:fetch, input.users.profile, "age")
          value :user_cities, fn(:fetch, input.users.profile, "city")
        end
      end
      
      test_data = {
        users: [
          { "name" => "Alice", "age" => 30, "city" => "New York" },
          { "name" => "Bob", "age" => 25, "city" => "London" },
          { "name" => "Charlie", "age" => 35, "city" => "Tokyo" }
        ]
      }
      
      runner = schema.from(test_data)
      
      expect(runner[:profiles]).to eq([
        {"name"=>"Alice", "age"=>30, "city"=>"New York"},
        {"name"=>"Bob", "age"=>25, "city"=>"London"},
        {"name"=>"Charlie", "age"=>35, "city"=>"Tokyo"}
      ])
      expect(runner[:user_names]).to eq(["Alice", "Bob", "Charlie"])
      expect(runner[:user_ages]).to eq([30, 25, 35])
      expect(runner[:user_cities]).to eq(["New York", "London", "Tokyo"])
    end

    it "handles nested element :any with complex hash structures" do
      schema = Module.new do
        extend Kumi::Schema
        
        schema do
          input do
            array :companies do
              string :company_name
              array :employees do
                element :any, :employee_data
              end
            end
          end
          
          value :company_names, input.companies.company_name
          value :employee_data, input.companies.employees.employee_data
          value :employee_names, fn(:fetch, input.companies.employees.employee_data, "name")
          value :departments, fn(:fetch, input.companies.employees.employee_data, "department")
          value :salaries, fn(:fetch, input.companies.employees.employee_data, "salary")
          
          # Aggregations
          value :total_salaries, fn(:sum, fn(:fetch, input.companies.employees.employee_data, "salary"))
          value :avg_salary_per_company, fn(:mean, fn(:fetch, input.companies.employees.employee_data, "salary"))
        end
      end
      
      test_data = {
        companies: [
          {
            company_name: "TechCorp",
            employees: [
              { "name" => "Alice", "department" => "Engineering", "salary" => 95000 },
              { "name" => "Bob", "department" => "Marketing", "salary" => 75000 }
            ]
          },
          {
            company_name: "DataCorp",
            employees: [
              { "name" => "Charlie", "department" => "Research", "salary" => 105000 },
              { "name" => "Diana", "department" => "Sales", "salary" => 80000 }
            ]
          }
        ]
      }
      
      runner = schema.from(test_data)
      
      expect(runner[:company_names]).to eq(["TechCorp", "DataCorp"])
      expect(runner[:employee_names]).to eq([["Alice", "Bob"], ["Charlie", "Diana"]])
      expect(runner[:departments]).to eq([["Engineering", "Marketing"], ["Research", "Sales"]])
      expect(runner[:salaries]).to eq([[95000, 75000], [105000, 80000]])
      expect(runner[:total_salaries]).to eq([170000, 185000])
      expect(runner[:avg_salary_per_company]).to eq([85000.0, 92500.0])
    end

    it "handles deep nesting with element :any and aggregations" do
      schema = Module.new do
        extend Kumi::Schema
        
        schema do
          input do
            hash :organization do
              string :org_name
              array :regions do
                string :region_name
                array :offices do
                  element :any, :office_info
                end
              end
            end
          end
          
          value :org_name, input.organization.org_name
          value :region_names, input.organization.regions.region_name
          value :office_infos, input.organization.regions.offices.office_info
          value :office_cities, fn(:fetch, input.organization.regions.offices.office_info, "city")
          value :office_sizes, fn(:fetch, input.organization.regions.offices.office_info, "employee_count")
          value :floor_areas, fn(:fetch, input.organization.regions.offices.office_info, "floor_area")
          
          # Complex aggregations across deep structure
          value :total_employees, fn(:sum, fn(:fetch, input.organization.regions.offices.office_info, "employee_count"))
          value :total_floor_area, fn(:sum, fn(:fetch, input.organization.regions.offices.office_info, "floor_area"))
          value :avg_office_size, fn(:mean, fn(:fetch, input.organization.regions.offices.office_info, "employee_count"))
        end
      end
      
      test_data = {
        organization: {
          org_name: "GlobalTech",
          regions: [
            {
              region_name: "North America",
              offices: [
                { "city" => "New York", "employee_count" => 150, "floor_area" => 5000 },
                { "city" => "San Francisco", "employee_count" => 200, "floor_area" => 7000 }
              ]
            },
            {
              region_name: "Europe",
              offices: [
                { "city" => "London", "employee_count" => 120, "floor_area" => 4500 },
                { "city" => "Berlin", "employee_count" => 80, "floor_area" => 3000 }
              ]
            }
          ]
        }
      }
      
      runner = schema.from(test_data)
      
      expect(runner[:org_name]).to eq("GlobalTech")
      expect(runner[:region_names]).to eq(["North America", "Europe"])
      expect(runner[:office_cities]).to eq([["New York", "San Francisco"], ["London", "Berlin"]])
      expect(runner[:office_sizes]).to eq([[150, 200], [120, 80]])
      expect(runner[:floor_areas]).to eq([[5000, 7000], [4500, 3000]])
      expect(runner[:total_employees]).to eq([350, 200])
      expect(runner[:total_floor_area]).to eq([12000, 7500])
      expect(runner[:avg_office_size]).to eq([175.0, 100.0])
    end

    it "supports dynamic hash keys and flexible structures" do
      schema = Module.new do
        extend Kumi::Schema
        
        schema do
          input do
            array :api_responses do
              element :any, :response_data
            end
          end
          
          value :response_data, input.api_responses.response_data
          value :status_codes, fn(:fetch, input.api_responses.response_data, "status")
          value :messages, fn(:fetch, input.api_responses.response_data, "message")
          
          # Simple classification based on status codes
          trait :success_response, fn(:any?, fn(:fetch, input.api_responses.response_data, "status") == 200)
          trait :error_response, fn(:any?, fn(:fetch, input.api_responses.response_data, "status") >= 400)
          
          value :response_type do
            on error_response, "Error Response"
            on success_response, "Success Response"
            base "Other Response"
          end
        end
      end
      
      test_data = {
        api_responses: [
          { "status" => 200, "message" => "Success", "user" => {"id" => 123, "name" => "Alice"} },
          { "status" => 404, "message" => "Not Found", "error" => {"code" => "USER_NOT_FOUND"} },
          { "status" => 500, "message" => "Server Error", "debug" => {"trace" => "..."} }
        ]
      }
      
      runner = schema.from(test_data)
      
      expect(runner[:status_codes]).to eq([200, 404, 500])
      expect(runner[:messages]).to eq(["Success", "Not Found", "Server Error"])
      expect(runner[:response_type]).to eq("Error Response")  # trait evaluated at top level
    end

    it "works with mathematical operations on hash numeric values" do
      schema = Module.new do
        extend Kumi::Schema
        
        schema do
          input do
            array :transactions do
              element :any, :transaction_data
            end
          end
          
          value :amounts, fn(:fetch, input.transactions.transaction_data, "amount")
          value :fees, fn(:fetch, input.transactions.transaction_data, "fee")
          value :timestamps, fn(:fetch, input.transactions.transaction_data, "timestamp")
          
          # Mathematical operations on extracted values
          value :net_amounts, ref(:amounts) - ref(:fees)
          value :total_amount, fn(:sum, ref(:amounts))
          value :total_fees, fn(:sum, ref(:fees))
          value :net_total, ref(:total_amount) - ref(:total_fees)
          value :avg_transaction_size, fn(:mean, ref(:amounts))
        end
      end
      
      test_data = {
        transactions: [
          { "amount" => 100.50, "fee" => 2.50, "timestamp" => 1609459200, "type" => "purchase" },
          { "amount" => 75.25, "fee" => 1.75, "timestamp" => 1609545600, "type" => "refund" },
          { "amount" => 200.00, "fee" => 5.00, "timestamp" => 1609632000, "type" => "purchase" },
          { "amount" => 150.75, "fee" => 3.25, "timestamp" => 1609718400, "type" => "transfer" }
        ]
      }
      
      runner = schema.from(test_data)
      
      expect(runner[:amounts]).to eq([100.50, 75.25, 200.00, 150.75])
      expect(runner[:fees]).to eq([2.50, 1.75, 5.00, 3.25])
      expect(runner[:net_amounts]).to eq([98.0, 73.5, 195.0, 147.5])
      expect(runner[:total_amount]).to eq(526.5)
      expect(runner[:total_fees]).to eq(12.5)
      expect(runner[:net_total]).to eq(514.0)
      expect(runner[:avg_transaction_size]).to eq(131.625)
    end
  end

  describe "comparison with explicit hash objects" do
    it "demonstrates equivalent functionality between element :any and hash objects" do
      # Schema using element :any
      schema_element_any = Module.new do
        extend Kumi::Schema
        
        schema do
          input do
            array :users do
              element :any, :user_data
            end
          end
          
          value :names, fn(:fetch, input.users.user_data, "name")
          value :ages, fn(:fetch, input.users.user_data, "age")
        end
      end
      
      # Schema using explicit hash objects
      schema_hash_objects = Module.new do
        extend Kumi::Schema
        
        schema do
          input do
            array :users do
              hash :user_data do
                string :name
                integer :age
              end
            end
          end
          
          value :names, input.users.user_data.name
          value :ages, input.users.user_data.age
        end
      end
      
      # Test data for element :any approach
      test_data_any = {
        users: [
          { "name" => "Alice", "age" => 30 },
          { "name" => "Bob", "age" => 25 }
        ]
      }
      
      # Test data for hash objects approach (nested structure)
      test_data_hash = {
        users: [
          { user_data: { name: "Alice", age: 30 } },
          { user_data: { name: "Bob", age: 25 } }
        ]
      }
      
      runner_any = schema_element_any.from(test_data_any)
      runner_hash = schema_hash_objects.from(test_data_hash)
      
      # Both approaches produce the same results
      expect(runner_any[:names]).to eq(["Alice", "Bob"])
      expect(runner_any[:ages]).to eq([30, 25])
      expect(runner_hash[:names]).to eq(["Alice", "Bob"])
      expect(runner_hash[:ages]).to eq([30, 25])
    end
  end
end