# frozen_string_literal: true

# This fixture is designed to test location tracking accuracy
# Each error should point to the exact line where the syntax error occurs

class LocationTrackingTestSchema
  extend Kumi::Schema

  schema do
    input do
      integer :age
      string :name
    end

    # Line 15: Invalid value syntax - first argument should be symbol, not Array
    value value :bad_name, 42

    # Line 18: Invalid trait name - should be symbol, not string  
    trait "bad_trait_name", (input.age >= 18)

    # Line 21: Missing expression for value
    value :incomplete_value

    # Line 24: Invalid operator in trait
    trait :bad_operator, input.age, :invalid_op, 18

    # Line 27: Valid syntax for comparison
    value :valid_value, input.age + 10
  end
end