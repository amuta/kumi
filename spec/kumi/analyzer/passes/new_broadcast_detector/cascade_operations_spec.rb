# frozen_string_literal: true

require_relative '../../../../../lib/kumi/core/analyzer/passes/new_broadcast_detector'

RSpec.describe NewBroadcastDetector, "cascade operations" do
  include ASTFactory

  let(:errors) { [] }
  let(:state) { Kumi::Core::Analyzer::AnalysisState.new }

  def analyze_expression(input_meta, declarations)
    schema = syntax(:root, [], declarations, [])
    
    state_with_data = state
      .with(:inputs, input_meta)
      .with(:declarations, declarations.to_h { |d| [d.name, d] })
    
    detector = NewBroadcastDetector.new(schema, state_with_data)
    detector.run(errors)
    detector.metadata
  end

  describe "scalar cascades" do
    it "detects simple scalar cascade" do
      input_meta = { enabled: { type: :boolean } }
      
      # Define trait
      trait_expr = call(:==, input_ref(:enabled), lit(true))
      trait_decl = trait(:active, trait_expr)
      
      # Define cascade
      cascade_expression = syntax(:cascade_expr, [
        syntax(:case_expr, ref(:active), lit("Active"), loc: nil),
        syntax(:case_expr, lit(true), lit("Inactive"), loc: nil)
      ], loc: nil)
      
      metadata = analyze_expression(input_meta, [trait_decl, attr(:status, cascade_expression)])
      result = metadata[:status]
      
      expect(result[:operation_type]).to eq(:scalar)
      expect(result[:compilation][:evaluation_mode]).to eq(:direct)
    end
  end

  describe "vectorized cascades" do
    let(:input_meta) do
      {
        items: {
          type: :array,
          children: {
            status: { type: :string },
            price: { type: :float }
          }
        }
      }
    end

    it "detects cascade with vectorized conditions" do
      # Define trait
      trait_expr = call(:==, input_elem_ref([:items, :status]), lit("active"))
      trait_decl = trait(:available, trait_expr)
      
      # Define cascade
      cascade_expression = syntax(:cascade_expr, [
        syntax(:case_expr, ref(:available), lit("Available"), loc: nil),
        syntax(:case_expr, lit(true), lit("Unavailable"), loc: nil)
      ], loc: nil)
      
      metadata = analyze_expression(input_meta, [trait_decl, attr(:display_status, cascade_expression)])
      result = metadata[:display_status]
      
      expect(result[:operation_type]).to eq(:vectorized)
      expect(result[:cascade][:is_vectorized]).to eq(true)
      expect(result[:cascade][:processing]).to include(
        mode: :simple_array,
        depth: 1,
        strategy: :element_wise
      )
      
      # Check condition tracking
      condition = result[:cascade][:conditions].first
      expect(condition).to include(
        index: 0,
        type: :array,
        is_composite: false,
        source: include(kind: :declaration, name: :available)
      )
      
      # Check result tracking
      expect(result[:cascade][:results]).to match([
        include(index: 0, type: :scalar, source: include(kind: :literal, value: "Available")),
        include(index: 1, type: :scalar, source: include(kind: :literal, value: "Unavailable"))
      ])
    end

    it "detects cascade with array results" do
      # Define trait
      trait_expr = call(:>, input_elem_ref([:items, :price]), lit(100))
      trait_decl = trait(:expensive, trait_expr)
      
      # Define cascade with array results
      multiply_expr = call(:multiply, input_elem_ref([:items, :price]), lit(0.8))
      cascade_expression = syntax(:cascade_expr, [
        syntax(:case_expr, ref(:expensive), multiply_expr, loc: nil),
        syntax(:case_expr, lit(true), input_elem_ref([:items, :price]), loc: nil)
      ], loc: nil)
      
      metadata = analyze_expression(input_meta, [trait_decl, attr(:adjusted_prices, cascade_expression)])
      result = metadata[:adjusted_prices]
      
      expect(result[:operation_type]).to eq(:vectorized)
      expect(result[:cascade][:results]).to match([
        include(index: 0, type: :array, source: include(kind: :expression, operation: :multiply)),
        include(index: 1, type: :array, source: include(kind: :input_element, path: [:items, :price]))
      ])
    end
  end

  describe "cascade_and detection" do
    let(:input_meta) do
      {
        items: {
          type: :array,
          children: {
            status: { type: :string },
            price: { type: :float }
          }
        }
      }
    end

    it "detects cascade_and composite conditions" do
      # Define traits
      trait1_expr = call(:==, input_elem_ref([:items, :status]), lit("active"))
      trait1_decl = trait(:active, trait1_expr)
      
      trait2_expr = call(:>, input_elem_ref([:items, :price]), lit(50))
      trait2_decl = trait(:expensive, trait2_expr)
      
      # Define cascade_and condition
      cascade_and_expr = call(:cascade_and, ref(:active), ref(:expensive))
      
      # Define cascade
      cascade_expression = syntax(:cascade_expr, [
        syntax(:case_expr, cascade_and_expr, lit("Premium"), loc: nil),
        syntax(:case_expr, lit(true), lit("Standard"), loc: nil)
      ], loc: nil)
      
      metadata = analyze_expression(input_meta, [
        trait1_decl, 
        trait2_decl, 
        attr(:tier, cascade_expression)
      ])
      result = metadata[:tier]
      
      expect(result[:operation_type]).to eq(:vectorized)
      
      condition = result[:cascade][:conditions].first
      expect(condition[:is_composite]).to eq(true)
      expect(condition[:composite_parts]).to match([
        include(kind: :declaration, name: :active),
        include(kind: :declaration, name: :expensive)
      ])
    end
  end

  describe "processing strategy detection" do
    it "detects simple array processing for 1-level depth" do
      input_meta = {
        items: { type: :array, children: { price: { type: :float } } }
      }
      
      trait_expr = call(:>, input_elem_ref([:items, :price]), lit(100))
      trait_decl = trait(:expensive, trait_expr)
      
      cascade_expression = syntax(:cascade_expr, [
        syntax(:case_expr, ref(:expensive), lit("High"), loc: nil),
        syntax(:case_expr, lit(true), lit("Low"), loc: nil)
      ], loc: nil)
      
      metadata = analyze_expression(input_meta, [trait_decl, attr(:price_tier, cascade_expression)])
      
      expect(metadata[:price_tier][:cascade][:processing][:mode]).to eq(:simple_array)
    end

    it "detects nested array processing for 2-4 level depth" do
      input_meta = {
        regions: {
          type: :array,
          children: {
            offices: {
              type: :array,
              children: { revenue: { type: :float } }
            }
          }
        }
      }
      
      trait_expr = call(:>, input_elem_ref([:regions, :offices, :revenue]), lit(50000))
      trait_decl = trait(:high_performing, trait_expr)
      
      cascade_expression = syntax(:cascade_expr, [
        syntax(:case_expr, ref(:high_performing), lit("Star"), loc: nil),
        syntax(:case_expr, lit(true), lit("Standard"), loc: nil)
      ], loc: nil)
      
      metadata = analyze_expression(input_meta, [trait_decl, attr(:office_rating, cascade_expression)])
      
      expect(metadata[:office_rating][:cascade][:processing][:mode]).to eq(:nested_array)
      expect(metadata[:office_rating][:cascade][:processing][:depth]).to eq(2)
    end
  end

  describe "compilation hints for cascades" do
    let(:input_meta) do
      {
        items: {
          type: :array,
          children: { price: { type: :float } }
        }
      }
    end

    it "provides correct compilation hints for vectorized cascades" do
      trait_expr = call(:>, input_elem_ref([:items, :price]), lit(100))
      trait_decl = trait(:expensive, trait_expr)
      
      cascade_expression = syntax(:cascade_expr, [
        syntax(:case_expr, ref(:expensive), lit("High"), loc: nil),
        syntax(:case_expr, lit(true), lit("Low"), loc: nil)
      ], loc: nil)
      
      metadata = analyze_expression(input_meta, [trait_decl, attr(:tier, cascade_expression)])
      
      expect(metadata[:tier][:compilation]).to include(
        evaluation_mode: :cascade,
        expects_array_input: true,
        produces_array_output: true,
        requires_flattening: false,
        requires_dimension_check: false,
        requires_hierarchical_logic: false
      )
    end
  end
end