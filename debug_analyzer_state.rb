#!/usr/bin/env ruby

require_relative "lib/kumi"

module TestSchema
  extend Kumi::Schema

  schema skip_compiler: true do
    input do
      float :price
      integer :quantity
      float :tax_rate
    end

    trait :expensive, (input.price > 100.0)
    value :subtotal, input.price * input.quantity
    value :total_with_tax, subtotal * input.tax_rate
  end
end

puts "=== AST Structure ==="
ast = TestSchema.__syntax_tree__
puts ast.inspect

puts "\n=== Manual Analysis (without broadcast detector) ==="
# Skip the broken broadcast detector for now
passes = [
  Kumi::Core::Analyzer::Passes::NameIndexer,
  Kumi::Core::Analyzer::Passes::InputCollector,
  Kumi::Core::Analyzer::Passes::DeclarationValidator,
  Kumi::Core::Analyzer::Passes::SemanticConstraintValidator,
  Kumi::Core::Analyzer::Passes::DependencyResolver,
  Kumi::Core::Analyzer::Passes::UnsatDetector,
  Kumi::Core::Analyzer::Passes::Toposorter,
  Kumi::Core::Analyzer::Passes::BroadcastDetector,
  Kumi::Core::Analyzer::Passes::TypeInferencer,
  Kumi::Core::Analyzer::Passes::TypeConsistencyChecker,
  Kumi::Core::Analyzer::Passes::TypeChecker
]

analysis_result = Kumi::Analyzer.analyze!(ast, passes: passes)
puts analysis_result.class.inspect

puts "\n=== Analysis Result Fields ==="
puts "definitions: #{analysis_result.definitions&.keys}"
puts "dependency_graph: #{analysis_result.dependency_graph&.class}"
puts "leaf_map: #{analysis_result.leaf_map}"
puts "topo_order: #{analysis_result.topo_order}"
puts "decl_types: #{analysis_result.decl_types}"

puts "\n=== State Object ==="
state = analysis_result.state
puts "state type: #{state.class}"
puts "state methods: #{state.methods.grep(/get|set|keys/).sort}"

if state.respond_to?(:instance_variable_get)
  puts "internal state keys: #{state&.keys}"

  puts "\n=== Dependencies ==="
  puts state&.dig(:dependencies)

  puts "\n=== Types ==="
  puts state&.dig(:types)

  puts "\n=== Evaluation Order ==="
  puts state&.dig(:evaluation_order)

  puts "\n=== All Internal State Keys ==="
  puts state&.keys
end
