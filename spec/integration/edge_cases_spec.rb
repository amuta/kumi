# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Edge Cases" do
  describe "traits expressions" do
    xit "allows only expressions that returns a boolean value" do
    end
  end

  describe "value expressions" do
    xit "do not allow trait referenreces (outside cascade conditions)" do
    end
  end

  describe "Input field references" do
    xit "raise error when referencing a non-declared input field" do
      expect do
        module TestSchema19
          extend Kumi::Schema

          schema do
            input do
              string :person
            end

            value :person_name, input.person.name
          end
        end
      end.to raise_error(Kumi::Errors::Error, /reference to undeclared input `input.person.name`/)
    end
  end

  describe "Input/Declaration name collision" do
    it "allows input field and value declaration to have the same name without causing cycles" do
      module TestSchema1
        extend Kumi::Schema

        schema do
          input do
            integer :age
            integer :score
          end

          # Value with same name as input field - should not cause cycle
          value :age, input.age * 2
          value :doubled_score, input.score * 2
        end
      end

      result = TestSchema1.from(age: 25, score: 100)

      # The value :age should override the input :age in the output
      expect(result[:age]).to eq(50) # doubled age value, not input
      expect(result[:doubled_score]).to eq(200)
    end

    it "allows trait and input field to have the same name" do
      module TestSchema2
        extend Kumi::Schema

        schema do
          input do
            boolean :active
            integer :status
          end

          # Trait with same name as input field
          trait :active, input.status > 0
          trait :status_ok, input.status == 200

          value :result do
            on active, "active"
            base "inactive"
          end
        end
      end

      result = TestSchema2.from(active: false, status: 100)

      # The trait :active should be evaluated based on status > 0
      expect(result[:active]).to be(true) # trait evaluation
      expect(result[:result]).to eq("active")
    end

    it "handles complex name collisions with proper scoping" do
      module TestSchema3
        extend Kumi::Schema

        schema do
          input do
            integer :value
            integer :total
          end

          # Multiple declarations with overlapping names
          trait :is_high_value, input.value > 10
          value :value, input.value * 3
          value :total, input.total + ref(:value) # references the value :value, not input

          value :status do
            on is_high_value, "high value" # references the trait
            base "low value"
          end
        end
      end

      result = TestSchema3.from(value: 15, total: 100)

      expect(result[:value]).to eq(45) # 15 * 3
      expect(result[:total]).to eq(145) # 100 + 45
      expect(result[:status]).to eq("high value") # because trait is_high_value is true (15 > 10)
    end

    it "correctly resolves references when names collide" do
      module TestSchema4
        extend Kumi::Schema

        schema do
          input do
            integer :base
            integer :multiplier
          end

          value :base, input.base * 2
          value :result, ref(:base) * input.multiplier # should reference value :base, not input :base
        end
      end

      result = TestSchema4.from(base: 10, multiplier: 3)

      expect(result[:base]).to eq(20) # 10 * 2
      expect(result[:result]).to eq(60) # 20 * 3, not 30
    end

    it "handles self-referential names in cascades correctly" do
      module TestSchema5
        extend Kumi::Schema

        schema do
          input do
            integer :status
          end

          trait :is_active, input.status > 0

          # Value with cascade that might seem self-referential
          value :status do
            on is_active, "active"
            base "inactive"
          end

          value :display, fn(:concat, "Status: ", ref(:status)) # should reference value :status
        end
      end

      result = TestSchema5.from(status: 1)
      expect(result[:status]).to eq("active")
      expect(result[:display]).to eq("Status: active")

      result2 = TestSchema5.from(status: 0)
      expect(result2[:status]).to eq("inactive")
      expect(result2[:display]).to eq("Status: inactive")
    end
  end

  describe "Array broadcasting edge cases" do
    it "handles empty arrays gracefully" do
      module TestSchema6
        extend Kumi::Schema

        schema do
          input do
            array :items do
              float :price
            end
          end

          value :total, fn(:sum, input.items.price)
          value :average, fn(:avg, input.items.price)
          value :max_price, fn(:max, input.items.price)
        end
      end

      result = TestSchema6.from(items: [])

      expect(result[:total]).to eq(0)
      expect(result[:average]).to be_nil # or whatever the expected behavior is
      expect(result[:max_price]).to be_nil
    end

    it "handles single-element arrays in broadcasting" do
      module TestSchema7
        extend Kumi::Schema

        schema do
          input do
            array :items do
              float :price
              integer :quantity
            end
          end

          value :subtotals, input.items.price * input.items.quantity
          value :total, fn(:sum, ref(:subtotals))
        end
      end

      result = TestSchema7.from(items: [{ price: 10.0, quantity: 2 }])

      expect(result[:subtotals]).to eq([20.0])
      expect(result[:total]).to eq(20.0)
    end
  end

  describe "Type edge cases" do
    it "handles nil values in optional fields" do
      module TestSchema8
        extend Kumi::Schema

        schema do
          input do
            any :optional_value
            integer :required_value
          end

          value :result, input.required_value * 2
        end
      end

      result = TestSchema8.from(optional_value: nil, required_value: 5)
      expect(result[:result]).to eq(10)
    end

    it "handles type coercion edge cases" do
      module TestSchema9
        extend Kumi::Schema

        schema do
          input do
            float :price
            integer :quantity
          end

          value :total, input.price * input.quantity
        end
      end

      # Integer provided where float expected
      result = TestSchema9.from(price: 10, quantity: 3)
      expect(result[:total]).to eq(30)

      # Float that's actually an integer value
      result2 = TestSchema9.from(price: 10.0, quantity: 3)
      expect(result2[:total]).to eq(30.0)
    end
  end

  describe "Cascade edge cases" do
    it "handles cascades with all conditions false" do
      module TestSchema10
        extend Kumi::Schema

        schema do
          input do
            integer :value
          end

          trait :is_negative, input.value < 0
          trait :is_huge, input.value > 1000

          value :category do
            on is_negative, "negative"
            on is_huge, "huge"
            base "normal"
          end
        end
      end

      result = TestSchema10.from(value: 50)
      expect(result[:category]).to eq("normal")
    end

    it "handles nested cascade references" do
      module TestSchema11
        extend Kumi::Schema

        schema do
          input do
            integer :level
          end

          trait :level_1, input.level == 1
          trait :level_2, input.level == 2
          trait :level_3, input.level == 3
          location
          value :tier do
            on level_3, "gold"
            on level_2, "silver"
            on level_1, "bronze"
            base "none"
          end

          value :bonus do
            on level_3, 100
            on level_2, 50
            on level_1, 25
            base 0
          end
        end
      end

      result = TestSchema11.from(level: 3)
      expect(result[:tier]).to eq("gold")
      expect(result[:bonus]).to eq(100)
    end
  end

  describe "Reference chain edge cases" do
    it "handles long reference chains" do
      module TestSchema12
        extend Kumi::Schema

        schema do
          input do
            integer :a
          end

          value :b, input.a * 2
          value :c, ref(:b) * 2
          value :d, ref(:c) * 2
          value :e, ref(:d) * 2
          value :f, ref(:e) * 2
          value :result, ref(:f) * 2 # a * 64
        end
      end

      result = TestSchema12.from(a: 1)
      expect(result[:result]).to eq(64)
    end

    it "handles diamond dependency patterns" do
      module TestSchema13
        extend Kumi::Schema

        schema do
          input do
            integer :base
          end

          value :left, input.base * 2
          value :right, input.base * 3
          value :combined, ref(:left) + ref(:right) # both depend on base
          value :final, ref(:combined) * 2
        end
      end

      result = TestSchema13.from(base: 10)
      expect(result[:left]).to eq(20)
      expect(result[:right]).to eq(30)
      expect(result[:combined]).to eq(50)
      expect(result[:final]).to eq(100)
    end
  end

  describe "Domain validation edge cases" do
    it "handles boundary values in domain ranges" do
      module TestSchema14
        extend Kumi::Schema

        schema do
          input do
            integer :age, domain: 18..65
          end

          value :doubled_age, input.age * 2
        end
      end

      # Test boundary values
      expect { TestSchema14.from(age: 18) }.not_to raise_error
      expect { TestSchema14.from(age: 65) }.not_to raise_error

      # Test outside boundaries
      expect { TestSchema14.from(age: 17) }.to raise_error(Kumi::Errors::InputValidationError, /:age value 17 is outside domain 18..65/)
      expect { TestSchema14.from(age: 66) }.to raise_error(Kumi::Errors::InputValidationError, /:age value 66 is outside domain 18..65/)
    end

    it "handles enum domains with nil values" do
      module TestSchema15
        extend Kumi::Schema

        schema do
          input do
            any :status, domain: ["active", "inactive", nil]
          end

          value :is_set, input.status.nil?
        end
      end

      result = TestSchema15.from(status: nil)
      expect(result[:is_set]).to be(true)

      result2 = TestSchema15.from(status: "active")
      expect(result2[:is_set]).to be(false)
    end
  end

  describe "Function edge cases" do
    it "handles functions with empty array arguments" do
      module TestSchema16
        extend Kumi::Schema

        schema do
          input do
            any :numbers # Array of numbers
          end

          value :sum_result, fn(:sum, input.numbers)
          value :any_result, fn(:any?, input.numbers)
          value :all_result, fn(:all?, input.numbers)
        end
      end

      result = TestSchema16.from(numbers: [])

      expect(result[:sum_result]).to eq(0)
      expect(result[:any_result]).to be(false)
      expect(result[:all_result]).to be(true) # vacuous truth
    end

    xit "handles division by zero gracefully" do
      module TestSchema17
        extend Kumi::Schema

        schema do
          input do
            float :numerator
            float :denominator
          end

          value :result, input.numerator / input.denominator
        end
      end

      expect { TestSchema17.from(numerator: 10.0, denominator: 0.0) }.to raise_error(ZeroDivisionError)
    end

    it "allows nil? over expressions and transform it into a call expression `!= nil`" do
      module TestSchema18
        extend Kumi::Schema

        schema do
          input do
            any :name
            array :logs do
              element :integer, :log_date
            end
          end

          value :dates, input.logs.log_date.nil?
          trait :no_name, input.name.nil?
        end
      end

      inputs = { name: nil, logs: [nil, "01/01/2001"] }
      expect(TestSchema18.from(inputs)[:no_name]).to eq(true)
      expect(TestSchema18.from(inputs)[:dates]).to eq([true, false])
    end
  end
end
