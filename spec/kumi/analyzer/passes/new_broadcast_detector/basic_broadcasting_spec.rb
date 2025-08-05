# frozen_string_literal: true

require_relative "../../../../../lib/kumi/core/analyzer/passes/new_broadcast_detector"

RSpec.describe NewBroadcastDetector, "basic broadcasting" do
  include ASTFactory

  let(:errors) { [] }
  let(:state) { Kumi::Core::Analyzer::AnalysisState.new }

  # Helper to analyze expressions and get metadata
  def analyze_expression(input_meta, declarations)
    schema = syntax(:root, [], declarations, [])

    state_with_data = state
                      .with(:inputs, input_meta)
                      .with(:declarations, declarations.to_h { |d| [d.name, d] })

    detector = NewBroadcastDetector.new(schema, state_with_data)
    detector.run(errors)
    detector.metadata
  end

  describe "array operation detection" do
    it "detects simple array field references" do
      input_meta = {
        items: {
          type: :array,
          children: { price: { type: :float } }
        }
      }

      expr = input_elem_ref(%i[items price])
      metadata = analyze_expression(input_meta, [attr(:prices, expr)])

      expect(metadata[:prices][:operation_type]).to eq(:array_reference)
      expect(metadata[:prices][:array_source]).to include(
        root: :items,
        path: %i[items price],
        dimensions: [:items],
        depth: 1,
        access_mode: :object
      )
    end

    it "detects scalar operations" do
      expr = call(:add, lit(1), lit(2))
      metadata = analyze_expression({}, [attr(:sum, expr)])

      expect(metadata[:sum][:operation_type]).to eq(:scalar)
      expect(metadata[:sum][:compilation]).to include(
        evaluation_mode: :direct,
        expects_array_input: false,
        produces_array_output: false
      )
    end
  end

  describe "broadcasting strategies" do
    let(:input_meta) do
      {
        items: {
          type: :array,
          children: {
            price: { type: :float },
            quantity: { type: :integer }
          }
        }
      }
    end

    it "detects zip_map for two array operands" do
      expr = call(:multiply,
                  input_elem_ref(%i[items price]),
                  input_elem_ref(%i[items quantity]))

      metadata = analyze_expression(input_meta, [attr(:subtotals, expr)])
      result = metadata[:subtotals]

      expect(result[:operation_type]).to eq(:vectorized)
      expect(result[:vectorization][:strategy]).to eq(:zip_map)
      expect(result[:vectorization][:operands]).to match([
                                                           {
                                                             index: 0,
                                                             type: :array,
                                                             source: include(
                                                               kind: :input_element,
                                                               path: %i[items price],
                                                               dimensions: [:items]
                                                             )
                                                           },
                                                           {
                                                             index: 1,
                                                             type: :array,
                                                             source: include(
                                                               kind: :input_element,
                                                               path: %i[items quantity],
                                                               dimensions: [:items]
                                                             )
                                                           }
                                                         ])
    end

    it "detects broadcast_scalar for array + scalar" do
      expr = call(:multiply,
                  input_elem_ref(%i[items price]),
                  lit(0.9))

      metadata = analyze_expression(input_meta, [attr(:discounted, expr)])
      result = metadata[:discounted]

      expect(result[:operation_type]).to eq(:vectorized)
      expect(result[:vectorization][:strategy]).to eq(:broadcast_scalar)
      expect(result[:vectorization][:operands][0][:type]).to eq(:array)
      expect(result[:vectorization][:operands][1][:type]).to eq(:scalar)
      expect(result[:vectorization][:operands][1][:source]).to include(
        kind: :literal,
        value: 0.9
      )
    end

    it "detects broadcast_scalar_first for scalar + array" do
      expr = call(:multiply,
                  lit(0.9),
                  input_elem_ref(%i[items price]))

      metadata = analyze_expression(input_meta, [attr(:discounted, expr)])
      result = metadata[:discounted]

      expect(result[:operation_type]).to eq(:vectorized)
      expect(result[:vectorization][:strategy]).to eq(:broadcast_scalar_first)
      expect(result[:vectorization][:operands][0][:type]).to eq(:scalar)
      expect(result[:vectorization][:operands][1][:type]).to eq(:array)
    end
  end

  describe "dimension tracking" do
    it "tracks same-level dimensions" do
      input_meta = {
        items: {
          type: :array,
          children: {
            price: { type: :float },
            quantity: { type: :integer }
          }
        }
      }

      expr = call(:multiply,
                  input_elem_ref(%i[items price]),
                  input_elem_ref(%i[items quantity]))

      metadata = analyze_expression(input_meta, [attr(:result, expr)])
      dimension_info = metadata[:result][:vectorization][:dimension_info]

      expect(dimension_info).to include(
        compatible: true,
        mode: :same_level,
        primary_dimension: [:items]
      )
    end
  end

  describe "compilation hints" do
    it "provides correct hints for vectorized operations" do
      input_meta = {
        items: {
          type: :array,
          children: { price: { type: :float } }
        }
      }

      expr = call(:multiply, input_elem_ref(%i[items price]), lit(2))
      metadata = analyze_expression(input_meta, [attr(:doubled, expr)])

      expect(metadata[:doubled][:compilation]).to include(
        evaluation_mode: :broadcast,
        expects_array_input: true,
        produces_array_output: true,
        requires_flattening: false,
        requires_dimension_check: false
      )
    end
  end
end
