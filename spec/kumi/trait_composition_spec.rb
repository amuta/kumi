# frozen_string_literal: true

require "spec_helper"

# This needs to be define outside of the context block - because we intercept
# operators and ruby does not allow to redefine operators outside a Module context
schema_class = Class.new do
  extend Kumi::Schema

  schema do
    input do
      integer :age
      integer :account_balance
      boolean :verified
    end

    trait :adult, input.age, :>=, 18
    trait :ancient, input.age, :>=, 65
    trait :wealthy, input.account_balance, :>, 100_000

    # Test various composition patterns
    trait :rich_ancient, adult & ancient & ref(:wealthy)
    trait :verified_adult, adult & ref(:verified_check)
    trait :simple_combo, adult & wealthy
    trait :complex_mix, ancient & wealthy & ref(:verified_check)

    # Helper for verification check
    trait :verified_check, input.verified, :==, true
  end
end

RSpec.describe "Trait Composition" do
  describe "bare identifier composition with & operator" do
    context "with rich ancient person" do
      let(:data) { { age: 70, account_balance: 150_000, verified: true } }
      let(:runner) { schema_class.from(data) }

      it "evaluates rich_ancient trait correctly" do
        expect(runner[:rich_ancient]).to be true
      end

      it "evaluates verified_adult trait correctly" do
        expect(runner[:verified_adult]).to be true
      end

      it "evaluates simple_combo trait correctly" do
        expect(runner[:simple_combo]).to be true
      end

      it "evaluates complex_mix trait correctly" do
        expect(runner[:complex_mix]).to be true
      end
    end

    context "with young wealthy person" do
      let(:data) { { age: 25, account_balance: 150_000, verified: true } }
      let(:runner) { schema_class.from(data) }

      it "evaluates rich_ancient trait correctly (should be false)" do
        expect(runner[:rich_ancient]).to be false
      end

      it "evaluates verified_adult trait correctly" do
        expect(runner[:verified_adult]).to be true
      end

      it "evaluates simple_combo trait correctly" do
        expect(runner[:simple_combo]).to be true
      end

      it "evaluates complex_mix trait correctly (should be false)" do
        expect(runner[:complex_mix]).to be false
      end
    end

    context "with poor ancient person" do
      let(:data) { { age: 70, account_balance: 50_000, verified: false } }
      let(:runner) { schema_class.from(data) }

      it "evaluates rich_ancient trait correctly (should be false)" do
        expect(runner[:rich_ancient]).to be false
      end

      it "evaluates verified_adult trait correctly (should be false)" do
        expect(runner[:verified_adult]).to be false
      end

      it "evaluates simple_combo trait correctly (should be false)" do
        expect(runner[:simple_combo]).to be false
      end

      it "evaluates complex_mix trait correctly (should be false)" do
        expect(runner[:complex_mix]).to be false
      end
    end
  end

  describe "backward compatibility" do
    it "works alongside existing ref() syntax" do
      schema_class = Class.new do
        extend Kumi::Schema

        schema do
          input do
            integer :age
            boolean :verified
          end

          trait :adult, (input.age >= 18)
          trait :verified_person, (input.verified == true)

          # Mix new bare identifier syntax with existing ref() syntax
          trait :mixed_syntax, adult & ref(:verified_person)
        end
      end

      data = { age: 25, verified: true }
      runner = schema_class.from(data)

      expect(runner[:mixed_syntax]).to be true
    end

    it "maintains existing trait behavior unchanged" do
      schema_class = Class.new do
        extend Kumi::Schema

        schema do
          input do
            integer :score
          end

          trait :high_score, (input.score > 80)

          # Traditional trait usage should still work
          value :score_category do
            on :high_score, "excellent"
            base "average"
          end
        end
      end

      data = { score: 90 }
      runner = schema_class.from(data)

      expect(runner[:high_score]).to be true
      expect(runner[:score_category]).to eq "excellent"
    end
  end

  describe "dependency resolution" do
    it "correctly resolves dependencies in trait composition" do
      schema_class = Class.new do
        extend Kumi::Schema

        schema do
          input do
            integer :age
            integer :income
          end

          trait :adult, (input.age >= 18)
          trait :eligible, adult & (input.income > 50_000)

          # Trait that depends on composed trait
          value :status do
            on :eligible, "qualified"
            base "not_qualified"
          end
        end
      end

      data = { age: 30, income: 60_000 }
      runner = schema_class.from(data)

      expect(runner[:eligible]).to be true
      expect(runner[:status]).to eq "qualified"
    end
  end
end
