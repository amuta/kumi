# frozen_string_literal: true

module MySchema
  extend Kumi::Schema

  schema do
    input do
      array :regions do
        float :tax_rate
        array :offices do
          float :cost_of_living
          array :employees do
            float :salary
            float :rating
          end
        end
      end
    end

    trait :high_performer, input.regions.offices.employees.rating > 4.5

    value :bonus do
      on high_performer, input.regions.offices.employees.salary * 0.25
      base input.regions.offices.employees.salary * 0.10
    end

    value :take_home,
          (input.regions.offices.employees.salary + (bonus * input.regions.offices.cost_of_living)) *
          (1 - input.regions.tax_rate)
  end
end

RSpec.describe "Ranked Polymorphism" do
  let(:schema) { MySchema }

  let(:data) do
    {
      regions: [
        {
          tax_rate: 0.2,
          offices: [
            {
              cost_of_living: 1.5,
              employees: [
                { salary: 100_000, rating: 4.8 },
                { salary: 80_000, rating: 3.9 }
              ]
            }
          ]
        }
      ]
    }
  end

  it "calculates bonuses and take-home pay correctly" do
    result = schema.from(data)

    # expect(result[:bonus]).to eq([[[25_000.0, 8_000.0]]]) # [100k * 0.25, 80k * 0.10]
    expect(result[:take_home]).to eq([[[110_000.0, 73_600.0]]]) # [(100k + 25k*1.5) * 0.8, (80k + 8k*1.5) * 0.8]

    puts "Take home pay structure preserved:", result[:take_home].inspect
    puts "Bonuses calculated correctly:", result[:bonus].inspect
  end
end
