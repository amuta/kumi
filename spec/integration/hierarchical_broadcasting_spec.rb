# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Hierarchical Broadcasting in Cascades" do
  describe "valid parent-to-child broadcasting" do
    it "allows team-level conditions with employee-level results" do
      schema = Class.new do
        extend Kumi::Schema

        schema do
          input do
            array :regions do
              array :offices do
                array :teams do
                  float :performance_score
                  array :employees do
                    float :salary
                    float :rating
                    string :level
                  end
                end
              end
            end
          end

          # Employee-level traits
          trait :high_performer, input.regions.offices.teams.employees.rating >= 4.5
          trait :senior_level, input.regions.offices.teams.employees.level == "senior"

          # Team-level trait (parent dimension)
          trait :top_team, input.regions.offices.teams.performance_score >= 0.9

          # This should work: team-level condition broadcasts to employee-level
          value :employee_bonus do
            on high_performer, senior_level, top_team,
               input.regions.offices.teams.employees.salary * 0.30
            on high_performer, top_team,
               input.regions.offices.teams.employees.salary * 0.20
            base input.regions.offices.teams.employees.salary * 0.05
          end
        end
      end

      data = {
        regions: [
          {
            offices: [
              {
                teams: [
                  {
                    performance_score: 0.95, # top_team = true
                    employees: [
                      { salary: 100_000, rating: 4.8, level: "senior" },   # all traits true → 30%
                      { salary: 80_000, rating: 3.5, level: "junior" }     # only top_team true → 5%
                    ]
                  },
                  {
                    performance_score: 0.8, # top_team = false
                    employees: [
                      { salary: 90_000, rating: 4.6, level: "senior" } # high_performer, senior_level true, but top_team false → 5%
                    ]
                  }
                ]
              }
            ]
          }
        ]
      }

      result = schema.from(data)

      # Verify traits evaluate correctly (structure-preserving behavior)
      # Structure: regions[0] → offices[0] → teams[0,1] → employees[2,1]
      expect(result[:high_performer]).to eq([[[[true, false], [true]]]])  # Team 0: [true, false], Team 1: [true]
      expect(result[:senior_level]).to eq([[[[true, false], [true]]]])    # Team 0: [true, false], Team 1: [true]
      expect(result[:top_team]).to eq([[[true, false]]]) # Team 0: true, Team 1: false

      # Verify cascading with hierarchical broadcasting (structure-preserving)
      bonus = result[:employee_bonus]
      expect(bonus).to eq([[[[30_000.0, 4_000.0], [4_500.0]]]]) # Team 0: [30%, 5%], Team 1: [5%]
    end

    it "allows office-level conditions with employee-level results" do
      schema = Class.new do
        extend Kumi::Schema

        schema do
          input do
            array :regions do
              array :offices do
                float :cost_of_living
                array :teams do
                  array :employees do
                    float :salary
                    float :rating
                  end
                end
              end
            end
          end

          # Employee-level trait
          trait :high_performer, input.regions.offices.teams.employees.rating >= 4.5

          # Office-level trait (broadcasts to all teams and employees in that office)
          trait :expensive_office, input.regions.offices.cost_of_living >= 1.5

          value :adjusted_salary do
            on high_performer, expensive_office,
               input.regions.offices.teams.employees.salary * 1.3
            on expensive_office,
               input.regions.offices.teams.employees.salary * 1.1
            base input.regions.offices.teams.employees.salary
          end
        end
      end

      data = {
        regions: [
          {
            offices: [
              {
                cost_of_living: 1.6, # expensive_office = true
                teams: [
                  {
                    employees: [
                      { salary: 100_000, rating: 4.8 },  # high_performer=true, expensive_office=true → 130%
                      { salary: 80_000, rating: 3.5 }    # high_performer=false, expensive_office=true → 110%
                    ]
                  }
                ]
              },
              {
                cost_of_living: 1.2, # expensive_office = false
                teams: [
                  {
                    employees: [
                      { salary: 90_000, rating: 4.6 } # high_performer=true, expensive_office=false → 100%
                    ]
                  }
                ]
              }
            ]
          }
        ]
      }

      result = schema.from(data)

      expect(result[:high_performer]).to eq([[[[true, false]], [[true]]]]) # Structure-preserving
      expect(result[:expensive_office]).to eq([[true, false]]) # Office-level trait
      expect(result[:adjusted_salary]).to eq([[[[130_000.0, 88_000.0]], [[90_000.0]]]]) # Structure-preserving
    end
  end

  describe "invalid cross-branch broadcasting" do
    it "rejects conditions from different branches" do
      expect do
        Class.new do
          extend Kumi::Schema

          schema do
            input do
              array :departments do
                string :name
                array :employees do
                  float :salary
                end
              end

              array :projects do
                string :status
                array :contributors do
                  string :role
                end
              end
            end

            # These are from different top-level branches - should not be mixable
            trait :high_salary, input.departments.employees.salary > 100_000
            trait :active_project, input.projects.status == "active"

            # This should fail - mixing different branch dimensions
            value :bonus do
              on high_salary, active_project, 1000
              base 0
            end
          end
        end
      end.to raise_error(Kumi::Core::Errors::SemanticError, /dimensional mismatch/)
    end

    it "rejects non-hierarchical same-level mixing" do
      expect do
        Class.new do
          extend Kumi::Schema

          schema do
            input do
              array :regions do
                array :offices do
                  string :city
                end
                array :warehouses do
                  string :location
                end
              end
            end

            # These are at same level but different branches under regions
            trait :london_office, input.regions.offices.city == "London"
            trait :uk_warehouse, input.regions.warehouses.location == "UK"

            # This should fail - offices and warehouses are sibling dimensions
            value :bonus do
              on london_office, uk_warehouse, 1000
              base 0
            end
          end
        end
      end.to raise_error(Kumi::Core::Errors::SemanticError, /dimensional mismatch/)
    end
  end

  describe "complex hierarchical scenarios" do
    it "handles multi-level hierarchical broadcasting" do
      schema = Class.new do
        extend Kumi::Schema

        schema do
          input do
            array :companies do
              string :country
              array :regions do
                float :tax_rate
                array :offices do
                  float :rent_cost
                  array :teams do
                    string :department
                    array :employees do
                      float :salary
                      string :level
                    end
                  end
                end
              end
            end
          end

          # Different hierarchical levels
          trait :us_company, input.companies.country == "US" # Level 1
          trait :low_tax_region, input.companies.regions.tax_rate < 0.2              # Level 2
          trait :expensive_office, input.companies.regions.offices.rent_cost > 1000  # Level 3
          trait :engineering_team, input.companies.regions.offices.teams.department == "Engineering"  # Level 4
          trait :senior_employee, input.companies.regions.offices.teams.employees.level == "senior"   # Level 5

          # Complex cascade mixing multiple hierarchical levels
          value :total_compensation do
            on us_company, low_tax_region, expensive_office, engineering_team, senior_employee,
               input.companies.regions.offices.teams.employees.salary * 1.5
            on us_company, engineering_team, senior_employee,
               input.companies.regions.offices.teams.employees.salary * 1.3
            on senior_employee,
               input.companies.regions.offices.teams.employees.salary * 1.1
            base input.companies.regions.offices.teams.employees.salary
          end
        end
      end

      # This should compile successfully since all dimensions are hierarchically related
      expect { schema }.not_to raise_error
    end
  end
end
