# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Export -> Import -> Analysis Pipeline" do
  include ASTFactory

  it "preserves all analyzer results for simple schema" do
    # Build a simple but complete schema
    inputs = [
      field_decl(:name, nil, :string),
      field_decl(:age, nil, :integer)
    ]

    attributes = [
      attr(:greeting, call(:concat, lit("Hello, "), field_ref(:name))),
      attr(:age_category, call(:conditional,
                               call(:>=, field_ref(:age), lit(18)),
                               lit("adult"),
                               lit("minor")))
    ]

    traits = [
      trait(:adult, call(:>=, field_ref(:age), lit(18))),
      trait(:has_name, call(:"!=", field_ref(:name), lit("")))
    ]

    original_ast = syntax(:root, inputs, attributes, traits)

    # Run original analysis
    original_analysis = Kumi::Analyzer.analyze!(original_ast)

    # Export and import
    json = Kumi::Export.to_json(original_ast)
    imported_ast = Kumi::Export.from_json(json)

    # Run analysis on imported AST
    imported_analysis = Kumi::Analyzer.analyze!(imported_ast)

    # Results must be identical
    expect(imported_analysis.definitions.keys).to match_array(original_analysis.definitions.keys)
    expect(imported_analysis.topo_order).to eq(original_analysis.topo_order)
    expect(imported_analysis.decl_types.keys).to match_array(original_analysis.decl_types.keys)

    # Verify dependency graph structure is preserved
    original_edges = original_analysis.dependency_graph
    imported_edges = imported_analysis.dependency_graph

    expect(imported_edges.keys).to match_array(original_edges.keys)

    # Check that each dependency list has the same targets
    original_edges.each do |node, deps|
      expect(imported_edges[node].map(&:to)).to match_array(deps.map(&:to))
    end
  end

  it "enables compilation of imported schemas" do
    # Build schema with dependencies
    inputs = [field_decl(:base_price, nil, :float)]

    attributes = [
      attr(:discount, call(:multiply, field_ref(:base_price), lit(0.1))),
      attr(:final_price, call(:subtract, field_ref(:base_price), binding_ref(:discount)))
    ]

    traits = [
      trait(:expensive, call(:>, binding_ref(:final_price), lit(100.0)))
    ]

    original_ast = syntax(:root, inputs, attributes, traits)

    # Export -> Import -> Compile -> Execute
    json = Kumi::Export.to_json(original_ast)
    imported_ast = Kumi::Export.from_json(json)

    analysis = Kumi::Analyzer.analyze!(imported_ast)
    compiled = Kumi::Compiler.compile(imported_ast, analyzer: analysis)

    # Should execute normally
    result = compiled.evaluate({ base_price: 120.0 })

    expect(result).to include(:discount, :final_price, :expensive)
    expect(result[:discount]).to eq(12.0)
    expect(result[:final_price]).to eq(108.0)
    expect(result[:expensive]).to be true
  end

  it "preserves complex nested expressions" do
    # Build schema with complex nesting
    inputs = [
      field_decl(:scores, nil, { array: :float }),
      field_decl(:threshold, nil, :float)
    ]

    attributes = [
      attr(:average, call(:divide,
                          call(:sum, field_ref(:scores)),
                          lit(3.0))),
      attr(:grade, call(:conditional,
                        call(:>=, binding_ref(:average), lit(90)),
                        lit("A"),
                        call(:conditional,
                             call(:>=, binding_ref(:average), lit(80)),
                             lit("B"),
                             lit("C"))))
    ]

    original_ast = syntax(:root, inputs, attributes, [])

    # Round-trip and analyze
    json = Kumi::Export.to_json(original_ast)
    imported_ast = Kumi::Export.from_json(json)

    analysis = Kumi::Analyzer.analyze!(imported_ast)
    compiled = Kumi::Compiler.compile(imported_ast, analyzer: analysis)

    # Test execution with nested calls
    result = compiled.evaluate({ scores: [85, 92, 88], threshold: 80.0 })

    expect(result[:average]).to be_within(0.01).of(88.33)
    expect(result[:grade]).to eq("B")
  end

  it "handles empty schema correctly" do
    original_ast = syntax(:root, [], [], [])

    json = Kumi::Export.to_json(original_ast)
    imported_ast = Kumi::Export.from_json(json)

    analysis = Kumi::Analyzer.analyze!(imported_ast)
    compiled = Kumi::Compiler.compile(imported_ast, analyzer: analysis)

    result = compiled.evaluate({})
    expect(result).to eq({})
  end
end
