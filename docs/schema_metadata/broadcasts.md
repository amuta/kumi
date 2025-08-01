# Broadcasts Metadata

Array broadcasting operation analysis for vectorized computations.

## Structure

```ruby
state[:broadcasts] = {
  array_fields: Hash,
  vectorized_operations: Hash,
  reduction_operations: Hash
}
```

## Array Fields

```ruby
array_fields: {
  :line_items => {
    element_fields: [:price, :quantity, :name],
    element_types: { price: :float, quantity: :integer, name: :string }
  }
}
```

## Vectorized Operations

```ruby
vectorized_operations: {
  :item_totals => {
    operation: :multiply,
    vectorized_args: { 0 => true, 1 => true }
  }
}
```

## Reduction Operations

```ruby
reduction_operations: {
  :total_amount => {
    function: :sum,
    source: :array_field
  }
}
```

## Usage

- Compiler optimizations
- Parallel execution
- Type inference
- Performance analysis