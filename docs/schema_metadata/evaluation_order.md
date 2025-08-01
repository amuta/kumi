# Evaluation Order Metadata

Topologically sorted order for safe declaration evaluation.

## Structure

```ruby
state[:evaluation_order] = [:name1, :name2, :name3, ...]
```

## Example

```ruby
[:income, :deductions, :taxable_income, :tax_rate, :tax_amount, :adult, :status]
```

## Properties

- Dependencies appear before dependents  
- Handles conditional cycles in cascades
- Deterministic ordering
- Leaf nodes typically appear first

## Usage

- Compilation order
- Evaluation sequencing  
- Optimization planning
- Parallel execution grouping