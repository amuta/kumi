# Schema Metadata Examples

For comprehensive API documentation with detailed examples, see the YARD documentation in the SchemaMetadata class.

## Basic Usage

```ruby
class TaxSchema
  extend Kumi::Schema

  schema do
    input do
      integer :income, domain: 0..1_000_000
      string :filing_status, domain: %w[single married]
      integer :age, domain: 18..100
    end

    trait :adult, (input.age >= 18)
    trait :high_income, (input.income > 100_000)

    value :tax_rate do
      on high_income, 0.25
      base 0.15
    end

    value :tax_amount, input.income * tax_rate
  end
end

# Access schema metadata - clean object interface!
metadata = TaxSchema.schema_metadata

# Processed semantic metadata (rich, transformed from AST)
puts metadata.inputs
# => { :income => { type: :integer, domain: {...}, required: true }, ... }

puts metadata.values
# => { :tax_rate => { type: :float, cascade: {...} }, ... }

puts metadata.traits  
# => { :adult => { type: :boolean, condition: "input.age >= 18" }, ... }

# Raw analyzer state (direct from analysis passes)
puts metadata.evaluation_order
# => [:adult, :high_income, :tax_rate, :tax_amount]

puts metadata.dependencies
# => { :tax_amount => [#<Edge to: :tax_rate>, #<Edge to: :income>], ... }

puts metadata.inferred_types
# => { :adult => :boolean, :tax_rate => :float, :tax_amount => :float }

# Serializable processed hash
processed_hash = metadata.to_h
puts processed_hash.keys
# => [:inputs, :values, :traits, :functions]

# Raw analyzer state (contains AST nodes)
raw_state = metadata.analyzer_state
puts raw_state.keys
# => [:declarations, :inputs, :dependencies, :dependents, :leaves, :evaluation_order, :inferred_types, :cascades, :broadcasts]
```

## Tool Integration

```ruby
# Form generator example
def generate_form_fields(schema_class)
  metadata = schema_class.schema_metadata
  
  metadata.inputs.map do |field_name, field_info|
    case field_info[:type]
    when :integer
      create_number_input(field_name, field_info[:domain])
    when :string
      create_select_input(field_name, field_info[:domain])
    when :boolean
      create_checkbox_input(field_name)
    end
  end
end

# Dependency analysis example  
def analyze_field_dependencies(schema_class, field_name)
  metadata = schema_class.schema_metadata
  
  # Find what depends on this field
  dependents = metadata.dependents[field_name] || []
  
  # Find what this field depends on
  dependencies = metadata.dependencies[field_name]&.map(&:to) || []
  
  { affects: dependents, requires: dependencies }
end
```