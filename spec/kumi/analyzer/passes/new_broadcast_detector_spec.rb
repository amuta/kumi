# frozen_string_literal: true

# require_relative '../../../../lib/kumi/core/analyzer/passes/new_broadcast_detector'

RSpec.describe NewBroadcastDetector do
  include ASTFactory

  let(:errors) { [] }
  let(:state) { Kumi::Core::Analyzer::AnalysisState.new }

  # Helper to analyze expressions and get metadata
  def analyze_expression(input_meta, declarations)
    schema = syntax(:root, [], declarations, [])

    state_with_data = state
                      .with(:inputs, input_meta)
                      .with(:declarations, declarations.to_h { |d| [d.name, d] })

    # Here we'll use our new detector
    detector = NewBroadcastDetector.new(schema, state_with_data)
    detector.run(errors)
    detector.metadata
  end

  describe "basic vectorized operations" do
    it "detects zip_map for two array operands" do
      # input.items.price * input.items.quantity
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

      metadata = analyze_expression(input_meta, [attr(:subtotals, expr)])

      expect(metadata[:subtotals]).to eq({
                                           operation_type: :vectorized,
                                           vectorization: {
                                             strategy: :zip_map,
                                             array_length_source: %i[items price],
                                             operand_types: [
                                               { index: 0, type: :array, source: "input.items.price" },
                                               { index: 1, type: :array, source: "input.items.quantity" }
                                             ]
                                           }
                                         })
    end

    it "detects broadcast_scalar for array + scalar" do
      # input.items.price * 0.9
      input_meta = {
        items: {
          type: :array,
          children: { price: { type: :float } }
        }
      }

      expr = call(:multiply,
                  input_elem_ref(%i[items price]),
                  lit(0.9))

      metadata = analyze_expression(input_meta, [attr(:discounted, expr)])

      expect(metadata[:discounted]).to eq({
                                            operation_type: :vectorized,
                                            vectorization: {
                                              strategy: :broadcast_scalar,
                                              array_length_source: %i[items price],
                                              operand_types: [
                                                { index: 0, type: :array, source: "input.items.price" },
                                                { index: 1, type: :scalar, source: "literal_0.9" }
                                              ]
                                            }
                                          })
    end

    it "detects broadcast_scalar_first for scalar + array" do
      # 0.9 * input.items.price
      input_meta = {
        items: {
          type: :array,
          children: { price: { type: :float } }
        }
      }

      expr = call(:multiply,
                  lit(0.9),
                  input_elem_ref(%i[items price]))

      metadata = analyze_expression(input_meta, [attr(:discounted, expr)])

      expect(metadata[:discounted]).to eq({
                                            operation_type: :vectorized,
                                            vectorization: {
                                              strategy: :broadcast_scalar_first,
                                              array_length_source: %i[items price],
                                              operand_types: [
                                                { index: 0, type: :scalar, source: "literal_0.9" },
                                                { index: 1, type: :array, source: "input.items.price" }
                                              ]
                                            }
                                          })
    end
  end

  describe "reduction operations" do
    it "detects reduction operations" do
      # fn(:sum, input.items.price)
      input_meta = {
        items: {
          type: :array,
          children: { price: { type: :float } }
        }
      }

      expr = call(:sum, input_elem_ref(%i[items price]))

      metadata = analyze_expression(input_meta, [attr(:total, expr)])

      expect(metadata[:total]).to eq({
                                       operation_type: :reduction,
                                       reduction: {
                                         function: :sum,
                                         input_source: %i[items price],
                                         flatten_args: [0]
                                       }
                                     })
    end
  end

  describe "cascade operations" do
    it "detects scalar cascade" do
      # value :status do
      #   on available, "Available"
      #   base "Unavailable"
      # end
      input_meta = {
        items: {
          type: :array,
          children: { status: { type: :string } }
        }
      }

      # First define the trait
      trait_expr = call(:==, input_elem_ref(%i[items status]), lit("active"))
      trait_decl = trait(:available, trait_expr)

      # Then the cascade
      cascade_expression = syntax(:cascade_expr, [
                                    syntax(:case_expr, ref(:available), lit("Available"), loc: nil),
                                    syntax(:case_expr, lit(true), lit("Unavailable"), loc: nil)
                                  ], loc: nil)

      metadata = analyze_expression(input_meta, [trait_decl, attr(:display_status, cascade_expression)])

      expect(metadata[:display_status]).to eq({
                                                operation_type: :vectorized,
                                                cascade: {
                                                  is_vectorized: true,
                                                  array_length_source: %i[items status],
                                                  conditions: [
                                                    { type: :array, source: "available" }
                                                  ],
                                                  results: [
                                                    { type: :scalar, source: "literal_Available" },
                                                    { type: :scalar, source: "literal_Unavailable" }
                                                  ]
                                                }
                                              })
    end

    it "detects mixed cascade with array results" do
      # value :adjusted_prices do
      #   on expensive, fn(:multiply, input.items.price, 0.8)
      #   base input.items.price
      # end
      input_meta = {
        items: {
          type: :array,
          children: { price: { type: :float } }
        }
      }

      # Define expensive trait
      trait_expr = call(:>, input_elem_ref(%i[items price]), lit(100))
      trait_decl = trait(:expensive, trait_expr)

      # Define cascade with array results
      multiply_expr = call(:multiply, input_elem_ref(%i[items price]), lit(0.8))
      cascade_expression = syntax(:cascade_expr, [
                                    syntax(:case_expr, ref(:expensive), multiply_expr, loc: nil),
                                    syntax(:case_expr, lit(true), input_elem_ref(%i[items price]), loc: nil)
                                  ], loc: nil)

      metadata = analyze_expression(input_meta, [trait_decl, attr(:adjusted_prices, cascade_expression)])

      expect(metadata[:adjusted_prices]).to eq({
                                                 operation_type: :vectorized,
                                                 cascade: {
                                                   is_vectorized: true,
                                                   array_length_source: %i[items price],
                                                   conditions: [
                                                     { type: :array, source: "expensive" }
                                                   ],
                                                   results: [
                                                     { type: :array, source: "multiply_expression" },
                                                     { type: :array, source: "input.items.price" }
                                                   ]
                                                 }
                                               })
    end
  end

  describe "scalar operations" do
    it "detects scalar operations" do
      # 1 + 2
      expr = call(:add, lit(1), lit(2))

      metadata = analyze_expression({}, [attr(:sum, expr)])

      expect(metadata[:sum]).to eq({
                                     operation_type: :scalar
                                   })
    end
  end
end
