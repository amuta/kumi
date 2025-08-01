# Cascades Metadata

Cascade mutual exclusion analysis for safe conditional cycles.

## Structure

```ruby
state[:cascades] = {
  cascade_name => {
    condition_traits: Array,
    condition_count: Integer,
    all_mutually_exclusive: Boolean,
    exclusive_pairs: Integer,
    total_pairs: Integer
  }
}
```

## Example

```ruby
{
  :tax_rate => {
    condition_traits: [:single, :married],
    condition_count: 2,
    all_mutually_exclusive: true,
    exclusive_pairs: 1,
    total_pairs: 1
  }
}
```

## Fields

- `condition_traits`: Trait names used in cascade conditions
- `all_mutually_exclusive`: Whether all condition pairs are exclusive
- `exclusive_pairs`: Count of mutually exclusive pairs
- `total_pairs`: Total possible pairs

## Usage

- Cycle safety analysis
- Topological sorting
- Optimization detection
- Dependency validation