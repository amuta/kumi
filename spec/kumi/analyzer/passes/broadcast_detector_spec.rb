# frozen_string_literal: true

require_relative "../../../../lib/kumi/core/analyzer/passes/broadcast_detector"

RSpec.describe Kumi::Core::Analyzer::Passes::BroadcastDetector do
  include ASTFactory

  let(:errors) { [] }
  let(:state) { Kumi::Core::Analyzer::AnalysisState.new }

  # Helper to analyze expressions and get V2 metadata
  def analyze_expression(input_meta, declarations)
    schema = syntax(:root, [], declarations, [])

    state_with_data = state
                      .with(:inputs, input_meta)
                      .with(:declarations, declarations.to_h { |d| [d.name, d] })

    detector = Kumi::Core::Analyzer::Passes::BroadcastDetector.new(schema, state_with_data)
    result_state = detector.run(errors)
    result_state[:detector_metadata]
  end

  describe "Object Access Strategies" do
    let(:input_meta) do
      {
        line_items: {
          type: :array,
          children: {
            price: { type: :float },
            quantity: { type: :integer },
            category: { type: :string }
          }
        },
        regions: {
          type: :array,
          children: {
            target: { type: :float },
            offices: {
              type: :array,
              children: {
                performance: { type: :float }
              }
            }
          }
        },
        global_threshold: { type: :integer }
      }
    end

    describe "array_scalar_object strategy" do
      it "correctly identifies array field vs scalar value operations" do
        # input.line_items.price > 100
        expr = call(:>, 
                    input_elem_ref(%i[line_items price]),
                    lit(100))

        metadata = analyze_expression(input_meta, [trait(:expensive, expr)])
        result = metadata[:expensive]

        expect(result[:operation_type]).to eq(:vectorized)
        expect(result[:strategy]).to eq(:array_scalar_object)
        expect(result[:access_mode]).to eq(:object)
        expect(result[:dimension_mode]).to eq(:same_level)
        
        expect(result[:operands]).to match([
          {
            type: :array,
            source: {
              kind: :input_element,
              path: [:line_items, :price],
              depth: 1,
              root: :line_items
            }
          },
          {
            type: :scalar,
            source: {
              kind: :literal,
              value: 100
            }
          }
        ])
      end

      it "correctly identifies array field vs input field operations" do
        # input.line_items.price > input.global_threshold
        expr = call(:>, 
                    input_elem_ref(%i[line_items price]),
                    input_ref(:global_threshold))

        metadata = analyze_expression(input_meta, [trait(:above_threshold, expr)])
        result = metadata[:above_threshold]

        expect(result[:strategy]).to eq(:array_scalar_object)
        expect(result[:operands][1][:source][:kind]).to eq(:input_field)
        expect(result[:operands][1][:source][:name]).to eq(:global_threshold)
      end
    end

    describe "element_wise_object strategy" do
      it "correctly identifies element-wise operations between array fields" do
        # input.line_items.price * input.line_items.quantity
        expr = call(:multiply,
                    input_elem_ref(%i[line_items price]),
                    input_elem_ref(%i[line_items quantity]))

        metadata = analyze_expression(input_meta, [attr(:subtotals, expr)])
        result = metadata[:subtotals]

        expect(result[:operation_type]).to eq(:vectorized)
        expect(result[:strategy]).to eq(:element_wise_object)
        expect(result[:access_mode]).to eq(:object)
        expect(result[:dimension_mode]).to eq(:same_level)

        expect(result[:operands]).to match([
          {
            type: :array,
            source: {
              kind: :input_element,
              path: [:line_items, :price],
              depth: 1,
              root: :line_items
            }
          },
          {
            type: :array,  
            source: {
              kind: :input_element,
              path: [:line_items, :quantity],
              depth: 1,
              root: :line_items
            }
          }
        ])
      end

      it "correctly identifies comparison operations between array fields" do
        # input.line_items.price > input.line_items.quantity
        expr = call(:>,
                    input_elem_ref(%i[line_items price]),
                    input_elem_ref(%i[line_items quantity]))

        metadata = analyze_expression(input_meta, [trait(:price_exceeds_qty, expr)])
        result = metadata[:price_exceeds_qty]

        expect(result[:strategy]).to eq(:element_wise_object)
        expect(result[:dimension_mode]).to eq(:same_level)
      end
    end

    describe "parent_child_object strategy" do
      it "correctly identifies nested field vs parent field operations" do
        # input.regions.offices.performance > input.regions.target
        expr = call(:>,
                    input_elem_ref(%i[regions offices performance]),
                    input_elem_ref(%i[regions target]))

        metadata = analyze_expression(input_meta, [trait(:exceeds_target, expr)])
        result = metadata[:exceeds_target]

        expect(result[:operation_type]).to eq(:vectorized)
        expect(result[:strategy]).to eq(:parent_child_object)
        expect(result[:access_mode]).to eq(:object)
        expect(result[:dimension_mode]).to eq(:parent_child)

        expect(result[:operands]).to match([
          {
            type: :array,
            source: {
              kind: :input_element,
              path: [:regions, :offices, :performance],
              depth: 2,
              root: :regions
            }
          },
          {
            type: :array,
            source: {
              kind: :input_element,
              path: [:regions, :target],
              depth: 1,  
              root: :regions
            }
          }
        ])
      end
    end
  end

  describe "Vector Access Strategies" do
    # TODO: Add vector access tests when we have proper vector input syntax
    # For now, vector strategies are tested through the registry function tests
  end

  describe "Non-vectorized Operations" do
    let(:simple_input_meta) do
      {
        global_threshold: { type: :integer },
        line_items: {
          type: :array,
          children: {
            price: { type: :float }
          }
        }
      }
    end

    describe "scalar operations" do
      it "correctly identifies scalar-only operations" do
        # input.global_threshold * 2
        expr = call(:multiply,
                    input_ref(:global_threshold),
                    lit(2))

        metadata = analyze_expression(simple_input_meta, [attr(:doubled, expr)])
        result = metadata[:doubled]

        expect(result[:operation_type]).to eq(:scalar)
      end
    end

    describe "reduction operations" do
      it "correctly identifies reduction functions" do
        # fn(:sum, input.line_items.price)
        expr = call(:sum, input_elem_ref(%i[line_items price]))

        metadata = analyze_expression(simple_input_meta, [attr(:total_price, expr)])
        result = metadata[:total_price]

        expect(result[:operation_type]).to eq(:reduction)
        expect(result[:function]).to eq(:sum)
        expect(result[:input_source][:source][:kind]).to eq(:input_element)
        expect(result[:requires_flattening]).to eq(false)
      end

      it "correctly identifies reduction of computed values" do
        # First create a computed value
        subtotal_expr = call(:multiply,
                           input_elem_ref(%i[line_items price]),
                           input_elem_ref(%i[line_items quantity]))

        # Then sum it: fn(:sum, subtotals)  
        sum_expr = call(:sum, ref(:subtotals))

        metadata = analyze_expression(simple_input_meta, [
          attr(:subtotals, subtotal_expr),
          attr(:total, sum_expr)
        ])
        
        result = metadata[:total]

        expect(result[:operation_type]).to eq(:reduction)
        expect(result[:function]).to eq(:sum)
        expect(result[:input_source][:source][:kind]).to eq(:declaration)
        expect(result[:input_source][:source][:name]).to eq(:subtotals)
      end
    end

    describe "array reference operations" do
      it "correctly identifies direct array field references" do
        # input.line_items.price (direct reference, not operation)
        expr = input_elem_ref(%i[line_items price])

        metadata = analyze_expression(simple_input_meta, [attr(:prices, expr)])
        result = metadata[:prices]

        expect(result[:operation_type]).to eq(:array_reference)
        expect(result[:array_source][:root]).to eq(:line_items)
        expect(result[:array_source][:path]).to eq([:line_items, :price])
      end
    end
  end

  describe "Registry Call Information" do
    let(:registry_input_meta) do
      {
        line_items: {
          type: :array,
          children: {
            price: { type: :float },
            quantity: { type: :integer }
          }
        }
      }
    end

    it "provides complete registry call information for compilation" do
      # input.line_items.price * input.line_items.quantity
      expr = call(:multiply,
                  input_elem_ref(%i[line_items price]),
                  input_elem_ref(%i[line_items quantity]))

      metadata = analyze_expression(registry_input_meta, [attr(:subtotals, expr)])
      result = metadata[:subtotals]

      expect(result[:registry_call_info]).to include(
        function_name: :element_wise_object,
        operand_extraction: [
          {
            type: :array_field,
            path: [:line_items, :price],
            field: :price,
            access_mode: :object
          },
          {
            type: :array_field,
            path: [:line_items, :quantity],
            field: :quantity,
            access_mode: :object
          }
        ]
      )
    end
  end

  describe "Error Handling" do
    it "handles invalid expressions gracefully" do
      # This should not crash the detector
      metadata = analyze_expression({}, [attr(:invalid, lit("test"))])

      expect(errors).to be_empty  # Simple literals shouldn't cause errors
      expect(metadata[:invalid][:operation_type]).to eq(:scalar)
    end
  end
end