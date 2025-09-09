# frozen_string_literal: true

module MixedChainingSugar
  extend Kumi::Schema

  schema do
    input do
      float :base_salary
      float :bonus_percent
      integer :years_experience
    end

    # Chained arithmetic with mixed literals and expressions
    value :bonus_amount, input.base_salary * (input.bonus_percent / 100.0)
    value :total_salary, input.base_salary + ref(:bonus_amount)

    # Chained comparisons
    trait :well_paid, ref(:total_salary) >= 80_000.0
    trait :experienced, input.years_experience > 5
    trait :senior_well_paid, well_paid & experienced
  end
end

RSpec.describe "Sugar syntax mixed expression chaining" do
  describe "mixed_chaining_sugar schema" do
    it "handles complex expression chaining correctly" do
      data = { base_salary: 70_000.0, bonus_percent: 15.0, years_experience: 8 }
      runner = MixedChainingSugar.from(data)

      expect(runner[:bonus_amount]).to eq(10_500.0)
      expect(runner[:total_salary]).to eq(80_500.0)

      expect(runner[:well_paid]).to be true
      expect(runner[:experienced]).to be true
      expect(runner[:senior_well_paid]).to be true
    end

    it "handles inexperienced but well-paid scenario" do
      data = { base_salary: 90_000.0, bonus_percent: 10.0, years_experience: 3 }
      runner = MixedChainingSugar.from(data)

      expect(runner[:bonus_amount]).to eq(9_000.0)
      expect(runner[:total_salary]).to eq(99_000.0)

      expect(runner[:well_paid]).to be true
      expect(runner[:experienced]).to be false
      expect(runner[:senior_well_paid]).to be false
    end

    it "handles experienced but low-paid scenario" do
      data = { base_salary: 60_000.0, bonus_percent: 5.0, years_experience: 10 }
      runner = MixedChainingSugar.from(data)

      expect(runner[:bonus_amount]).to eq(3_000.0)
      expect(runner[:total_salary]).to eq(63_000.0)

      expect(runner[:well_paid]).to be false
      expect(runner[:experienced]).to be true
      expect(runner[:senior_well_paid]).to be false
    end

    it "handles zero bonus scenario" do
      data = { base_salary: 85_000.0, bonus_percent: 0.0, years_experience: 7 }
      runner = MixedChainingSugar.from(data)

      expect(runner[:bonus_amount]).to eq(0.0)
      expect(runner[:total_salary]).to eq(85_000.0)

      expect(runner[:well_paid]).to be true
      expect(runner[:experienced]).to be true
      expect(runner[:senior_well_paid]).to be true
    end

    it "handles high bonus percentage" do
      data = { base_salary: 50_000.0, bonus_percent: 80.0, years_experience: 6 }
      runner = MixedChainingSugar.from(data)

      expect(runner[:bonus_amount]).to eq(40_000.0)
      expect(runner[:total_salary]).to eq(90_000.0)

      expect(runner[:well_paid]).to be true
      expect(runner[:experienced]).to be true
      expect(runner[:senior_well_paid]).to be true
    end
  end
end
