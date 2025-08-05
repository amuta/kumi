# frozen_string_literal: true

require_relative "../../../../../lib/kumi/core/analyzer/passes/new_broadcast_detector"

RSpec.describe NewBroadcastDetector, "reduction operations" do
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

  describe "basic reductions" do
    let(:input_meta) do
      {
        items: {
          type: :array,
          children: { price: { type: :float } }
        }
      }
    end

    it "detects sum reduction" do
      expr = call(:sum, input_elem_ref(%i[items price]))
      metadata = analyze_expression(input_meta, [attr(:total, expr)])
      result = metadata[:total]

      expect(result[:operation_type]).to eq(:reduction)
      expect(result[:reduction][:function]).to eq(:sum)
      expect(result[:reduction][:input]).to include(
        source: include(
          kind: :input_element,
          path: %i[items price]
        ),
        requires_flattening: false,
        flatten_depth: 1
      )
    end

    it "detects max reduction" do
      expr = call(:max, input_elem_ref(%i[items price]))
      metadata = analyze_expression(input_meta, [attr(:highest, expr)])
      result = metadata[:highest]

      expect(result[:operation_type]).to eq(:reduction)
      expect(result[:reduction][:function]).to eq(:max)
    end

    it "provides correct compilation hints for reductions" do
      expr = call(:sum, input_elem_ref(%i[items price]))
      metadata = analyze_expression(input_meta, [attr(:total, expr)])

      expect(metadata[:total][:compilation]).to include(
        evaluation_mode: :reduce,
        expects_array_input: true,
        produces_array_output: false,
        requires_flattening: false
      )
    end
  end

  describe "nested array reductions" do
    let(:nested_input_meta) do
      {
        regions: {
          type: :array,
          children: {
            offices: {
              type: :array,
              children: {
                revenue: { type: :float }
              }
            }
          }
        }
      }
    end

    it "detects flattening requirements for nested arrays" do
      expr = call(:sum, input_elem_ref(%i[regions offices revenue]))
      metadata = analyze_expression(nested_input_meta, [attr(:total_revenue, expr)])
      result = metadata[:total_revenue]

      expect(result[:operation_type]).to eq(:reduction)
      expect(result[:array_source]).to include(
        root: :regions,
        path: %i[regions offices revenue],
        dimensions: %i[regions offices],
        depth: 2
      )
      expect(result[:reduction][:input]).to include(
        requires_flattening: true,
        flatten_depth: :all
      )
      expect(result[:compilation][:requires_flattening]).to eq(true)
    end
  end

  describe "reduction on scalar values" do
    it "treats reduction of scalar as scalar operation" do
      expr = call(:sum, lit(42))
      metadata = analyze_expression({}, [attr(:pointless, expr)])

      expect(metadata[:pointless][:operation_type]).to eq(:scalar)
    end
  end

  describe "reduction on derived arrays" do
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

    it "handles reduction of computed values" do
      # First compute subtotals, then sum them
      subtotal_expr = call(:multiply,
                           input_elem_ref(%i[items price]),
                           input_elem_ref(%i[items quantity]))
      sum_expr = call(:sum, ref(:subtotals))

      metadata = analyze_expression(input_meta, [
                                      attr(:subtotals, subtotal_expr),
                                      attr(:total, sum_expr)
                                    ])

      expect(metadata[:subtotals][:operation_type]).to eq(:vectorized)
      expect(metadata[:total][:operation_type]).to eq(:reduction)
      expect(metadata[:total][:reduction][:input][:source]).to include(
        kind: :declaration,
        name: :subtotals
      )
    end
  end
end
