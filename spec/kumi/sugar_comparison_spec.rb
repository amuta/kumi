# frozen_string_literal: true

module ComparisonSugar
  extend Kumi::Schema
  
  schema do
    input do
      integer :age
      float :score
    end

    trait :adult, input.age >= 18
    trait :minor, input.age < 18
    trait :teenager, input.age > 12
    trait :child, input.age <= 12
    trait :exact_age, input.age == 25
    trait :not_exact_age, input.age != 25
    trait :high_score, input.score >= 90.0
  end
end

RSpec.describe "Sugar syntax comparison operations" do
  describe "comparison_sugar schema" do
    context "with adult age" do
      it "correctly identifies adult vs minor" do
        data = { age: 25, score: 95.5 }
        runner = ComparisonSugar.from(data)

        expect(runner[:adult]).to be true
        expect(runner[:minor]).to be false
        expect(runner[:teenager]).to be true
        expect(runner[:child]).to be false
        expect(runner[:exact_age]).to be true
        expect(runner[:not_exact_age]).to be false
        expect(runner[:high_score]).to be true
      end
    end

    context "with child age" do
      it "correctly identifies child vs adult" do
        data = { age: 8, score: 85.0 }
        runner = ComparisonSugar.from(data)

        expect(runner[:adult]).to be false
        expect(runner[:minor]).to be true
        expect(runner[:teenager]).to be false
        expect(runner[:child]).to be true
        expect(runner[:exact_age]).to be false
        expect(runner[:not_exact_age]).to be true
        expect(runner[:high_score]).to be false
      end
    end

    context "with teenager age" do
      it "correctly identifies teenager status" do
        data = { age: 16, score: 92.0 }
        runner = ComparisonSugar.from(data)

        expect(runner[:adult]).to be false
        expect(runner[:minor]).to be true
        expect(runner[:teenager]).to be true
        expect(runner[:child]).to be false
        expect(runner[:high_score]).to be true
      end
    end

    context "with edge cases" do
      it "handles exact boundary values" do
        data = { age: 18, score: 90.0 }
        runner = ComparisonSugar.from(data)

        expect(runner[:adult]).to be true
        expect(runner[:minor]).to be false
        expect(runner[:high_score]).to be true
      end
    end
  end
end