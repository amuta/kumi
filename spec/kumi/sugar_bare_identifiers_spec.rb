# frozen_string_literal: true

module BareIdentifiersSugar
  extend Kumi::Schema

  schema do
    input do
      float :income
      integer :age
    end

    # Base values
    value :base_income, input.income
    value :person_age, input.age

    # Bare identifier arithmetic (no ref() needed)
    value :net_income, base_income * 0.8
    value :double_age, person_age * 2

    # Bare identifier arrays and indexing
    value :scores, [100, 85, 92]
    value :first_score, scores[0]
    value :second_score, scores[1]

    # Bare identifier comparisons
    trait :high_income, base_income >= 50_000.0
    trait :adult, person_age >= 18

    # Bare identifier logical operations
    trait :wealthy_adult, high_income & adult
  end
end

RSpec.describe "Sugar syntax bare identifier operations" do
  describe "bare_identifiers_sugar schema" do
    it "supports operators on bare identifiers without ref()" do
      data = { income: 75_000.0, age: 30 }
      runner = BareIdentifiersSugar.from(data)

      expect(runner[:base_income]).to eq(75_000.0)
      expect(runner[:person_age]).to eq(30)
      expect(runner[:net_income]).to eq(60_000.0)
      expect(runner[:double_age]).to eq(60)

      expect(runner[:first_score]).to eq(100)
      expect(runner[:second_score]).to eq(85)

      expect(runner[:high_income]).to be true
      expect(runner[:adult]).to be true
      expect(runner[:wealthy_adult]).to be true
    end

    it "handles low income scenarios" do
      data = { income: 30_000.0, age: 25 }
      runner = BareIdentifiersSugar.from(data)

      expect(runner[:net_income]).to eq(24_000.0)
      expect(runner[:high_income]).to be false
      expect(runner[:adult]).to be true
      expect(runner[:wealthy_adult]).to be false
    end

    it "handles minor age scenarios" do
      data = { income: 80_000.0, age: 16 }
      runner = BareIdentifiersSugar.from(data)

      expect(runner[:double_age]).to eq(32)
      expect(runner[:high_income]).to be true
      expect(runner[:adult]).to be false
      expect(runner[:wealthy_adult]).to be false
    end

    it "handles array indexing correctly" do
      data = { income: 50_000.0, age: 20 }
      runner = BareIdentifiersSugar.from(data)

      expect(runner[:scores]).to eq([100, 85, 92])
      expect(runner[:first_score]).to eq(100)
      expect(runner[:second_score]).to eq(85)
    end
  end
end
