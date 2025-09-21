# frozen_string_literal: true

module StringOpsSugar
  extend Kumi::Schema
  
  schema do
    input do
      string :name
    end

    # String equality (only supported operation)
    trait :is_john, input.name == "John"
    trait :not_jane, input.name != "Jane"
    trait :inverted_check, input.name == "Alice"
  end
end