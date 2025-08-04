module ArrayNestingWithContextPreservationSpec
  extend Kumi::Schema

  schema do
    input do
      array :regions do
        string :name
        float :tax_rate
        array :offices do
          string :city
          float :col_adjustment
          array :teams do
            string :name
            float :performance_score
            array :employees do
              string :name
              float :base_salary
              string :level
              float :rating
            end
          end
        end
      end
    end

    trait :high_performer, input.regions.offices.teams.employees.rating >= 4.5
    trait :senior_level, input.regions.offices.teams.employees.level == "senior"
    trait :top_team, input.regions.offices.teams.performance_score >= 0.9

    value :employee_bonus do
      on high_performer, senior_level, top_team,
         input.regions.offices.teams.employees.base_salary * 0.30
      on high_performer, top_team,
         input.regions.offices.teams.employees.base_salary * 0.20
      base input.regions.offices.teams.employees.base_salary * 0.05
    end

    value :location_adjusted_bonus,
          employee_bonus * input.regions.offices.col_adjustment

    value :take_home,
          (input.regions.offices.teams.employees.base_salary + location_adjusted_bonus) *
          (1 - input.regions.tax_rate)
  end
end

RSpec.describe "Array Nesting with Context Preservation" do
  let(:schema) { ArrayNestingWithContextPreservationSpec }

  let(:input_data) do
    {
      regions: [
        {
          name: "EMEA",
          tax_rate: 0.35,
          offices: [
            {
              city: "London",
              col_adjustment: 1.4,
              teams: [
                {
                  name: "Platform",
                  performance_score: 0.95,
                  employees: [
                    { name: "Alice", base_salary: 100_000, level: "senior", rating: 4.8 },
                    { name: "Bob", base_salary: 70_000, level: "mid", rating: 3.9 }
                  ]
                },
                {
                  name: "Data",
                  performance_score: 0.85,
                  employees: [
                    { name: "Charlie", base_salary: 90_000, level: "senior", rating: 4.6 }
                  ]
                }
              ]
            },
            {
              city: "Berlin",
              col_adjustment: 1.1,
              teams: [
                {
                  name: "Security",
                  performance_score: 0.92,
                  employees: [
                    { name: "Diana", base_salary: 85_000, level: "senior", rating: 4.7 }
                  ]
                }
              ]
            }
          ]
        },
        {
          name: "APAC",
          tax_rate: 0.30,
          offices: [
            {
              city: "Tokyo",
              col_adjustment: 1.3,
              teams: [
                {
                  name: "Mobile",
                  performance_score: 0.88,
                  employees: [
                    { name: "Emi", base_salary: 95_000, level: "senior", rating: 4.5 }
                  ]
                }
              ]
            }
          ]
        }
      ]
    }
  end

  describe "basic array calculations" do
    let(:result) { schema.from(input_data) }

    it "calculates values maintaining array structure" do
      take_home = result[:take_home]

      # Values are in nested array structure matching input
      expect(take_home[0][0][0][0]).to eq(92_300.0)  # Alice: (100k + 30k*1.4) * 0.65 = 92,300
      expect(take_home[0][0][0][1]).to eq(48_685.0)  # Bob: (70k + 3.5k*1.4) * 0.65 = 48,685
      expect(take_home[0][0][1][0]).to eq(62_595.0)  # Charlie: (90k + 4.5k*1.4) * 0.65 = 62,595 (base case: not top team)
      expect(take_home[0][1][0][0]).to eq(73_482.5)  # Diana: (85k + 25.5k*1.1) * 0.65 = 73,482.5
      expect(take_home[1][0][0][0]).to eq(70_822.5)  # Emi: (95k + 4.75k*1.3) * 0.70 = 70,822.5 (base case: not top team)
    end
  end
end
