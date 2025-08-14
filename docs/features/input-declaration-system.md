# Input Declarations

Declares expected inputs with types and domain constraints, separating input metadata from business logic.

## Declaration Syntax

```ruby
schema do
  input do
    string  :customer_name
    integer :age, domain: 18..120
    float   :balance, domain: 0.0..Float::INFINITY
    boolean :verified
    array   :tags, elem: { type: :string }
    hash    :metadata, key: { type: :string }, val: { type: :any }
    any     :flexible
    
    # Structured arrays with defined fields
    array :orders do
      hash :customer do
        string :name
        string :email
      end
      float :total
    end
    
    # Dynamic arrays with flexible elements
    array :api_responses do
      element :any, :response_data    # For unknown/flexible hash structures
    end
  end
  
  trait :adult, (input.age >= 18)
  value :status, input.verified ? "verified" : "pending"
  value :customer_emails, input.orders.customer.email                           # Structured access
  value :response_codes, fn(:fetch, input.api_responses.response_data, "status") # Dynamic access
end
```

## Domain Constraints

**Validation occurs at runtime:**
```ruby
schema.from(credit_score: 900)  # Domain: 300..850
# => InputValidationError: Field :credit_score value 900 is outside domain 300..850
```

**Constraint types:**
- Range domains: `domain: 18..120`
- Array domains: `domain: %w[active inactive]`
- Regex domains: `domain: /^[a-zA-Z]+$/`

## Validation Process

- Input data validated against declared field metadata
- Type validation checks value matches declared type
- Domain validation checks value satisfies constraints
- Detailed error messages for violations