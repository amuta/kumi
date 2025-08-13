# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Flattening Functions" do
  # TODO : Decide? does it even make sense to flatten?, with all the accessors now it would be usefu probably
  # to have aggregation across structure (which should be very easy)
  # flatten could be used, but I think it introduces ambiguity
  # I need to think of some cases that i would use flatten for calculating things inside the schema itself

  describe "structure-preserving vs explicit flattening" do
    xit "preserves structure by default and allows explicit flattening" do
      schema = Class.new do
        extend Kumi::Schema

        schema do
          input do
            array :regions do
              array :offices do
                array :teams do
                  array :employees do
                    float :rating
                    string :level
                  end
                end
              end
            end
          end

          # Structure-preserving (default behavior)
          trait :high_performer, input.regions.offices.teams.employees.rating >= 4.5
          trait :senior_level, input.regions.offices.teams.employees.level == "senior"

          # Explicit flattening operations
          value :high_performer_flat, fn(:flatten, high_performer)
          value :high_performer_one_level, fn(:flatten_one, high_performer)

          # Aggregation across structure
          value :any_high_performer, fn(:any_across, high_performer)
          value :all_high_performers, fn(:all_across, high_performer)
          value :total_employees, fn(:count_across, high_performer)

          # Demonstrate practical use case: flattened then aggregated
          value :high_performer_count, fn(:count_if, high_performer_flat)
        end
      end

      data = {
        regions: [
          {
            offices: [
              {
                teams: [
                  {
                    employees: [
                      { rating: 4.8, level: "senior" }, # true
                      { rating: 3.5, level: "junior" }   # false
                    ]
                  },
                  {
                    employees: [
                      { rating: 4.6, level: "senior" }   # true
                    ]
                  }
                ]
              }
            ]
          }
        ]
      }

      result = schema.from(data)

      # Structure-preserving behavior (default)
      expect(result[:high_performer]).to eq([[[[true, false], [true]]]])
      expect(result[:senior_level]).to eq([[[[true, false], [true]]]])

      # Explicit flattening
      expect(result[:high_performer_flat]).to eq([true, false, true])
      expect(result[:high_performer_one_level]).to eq([[[true, false], [true]]])

      # Aggregation across structure
      expect(result[:any_high_performer]).to be(true)
      expect(result[:all_high_performers]).to be(false)
      expect(result[:total_employees]).to eq(3)

      # Practical use case
      expect(result[:high_performer_count]).to eq(2) # 2 out of 3 employees are high performers
    end
  end

  describe "comparison with business expectations" do
    xit "shows when structure preservation vs flattening matters" do
      schema = Class.new do
        extend Kumi::Schema

        schema do
          input do
            array :departments do
              string :name
              array :teams do
                string :name
                array :employees do
                  float :salary
                  string :performance
                end
              end
            end
          end

          trait :high_performer, input.departments.teams.employees.performance == "excellent"

          # For HR: "Which employees are high performers?" (business wants flat list)
          value :high_performers_list, fn(:flatten, high_performer)

          # For Management: "Which teams have high performers?" (structure matters)
          value :teams_with_high_performers, fn(:any_across, high_performer)

          # For Budget: "How many high performers total?" (aggregate)
          value :total_high_performers, fn(:count_if, high_performers_list)
        end
      end

      data = {
        departments: [
          {
            name: "Engineering",
            teams: [
              {
                name: "Backend",
                employees: [
                  { salary: 120_000, performance: "excellent" },
                  { salary: 100_000, performance: "good" }
                ]
              },
              {
                name: "Frontend",
                employees: [
                  { salary: 110_000, performance: "excellent" }
                ]
              }
            ]
          },
          {
            name: "Sales",
            teams: [
              {
                name: "Enterprise",
                employees: [
                  { salary: 90_000, performance: "good" }
                ]
              }
            ]
          }
        ]
      }

      result = schema.from(data)

      # Structure preserved - can see which department/team each employee belongs to
      expect(result[:high_performer]).to eq([
                                              [
                                                [true, false],  # Engineering Backend: excellent, good
                                                [true]          # Engineering Frontend: excellent
                                              ],
                                              [
                                                [false] # Sales Enterprise: good
                                              ]
                                            ])

      # HR use case - flat list of all high performers
      expect(result[:high_performers_list]).to eq([true, false, true, false])

      # Management use case - any team has high performers (would need more complex logic for real use)
      expect(result[:teams_with_high_performers]).to be(true)

      # Budget use case - total count
      expect(result[:total_high_performers]).to eq(2)
    end
  end
end
