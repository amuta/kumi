# frozen_string_literal: true

require_relative '../../../../../lib/kumi/core/analyzer/passes/new_broadcast_detector'

RSpec.describe NewBroadcastDetector, "dimension validation" do
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

  describe "dimension compatibility checking" do
    it "validates same-level dimensions as compatible" do
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
        input_elem_ref([:items, :price]),
        input_elem_ref([:items, :quantity])
      )
      
      metadata = analyze_expression(input_meta, [attr(:subtotal, expr)])
      dimension_info = metadata[:subtotal][:vectorization][:dimension_info]
      
      expect(dimension_info).to include(
        compatible: true,
        mode: :same_level,
        primary_dimension: [:items]
      )
    end

    it "validates hierarchical dimensions as compatible" do
      input_meta = {
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
        }
      }
      
      # offices.performance vs regions.target (child vs parent)
      expr = call(:>,
        input_elem_ref([:regions, :offices, :performance]),
        input_elem_ref([:regions, :target])
      )
      
      metadata = analyze_expression(input_meta, [attr(:exceeds_target, expr)])
      dimension_info = metadata[:exceeds_target][:vectorization][:dimension_info]
      
      expect(dimension_info).to include(
        compatible: true,
        mode: :hierarchical,
        primary_dimension: [:regions, :offices]
      )
      expect(dimension_info[:all_dimensions]).to contain_exactly(
        [:regions],
        [:regions, :offices]
      )
    end

    it "detects incompatible sibling dimensions" do
      input_meta = {
        products: {
          type: :array,
          children: { price: { type: :float } }
        },
        orders: {
          type: :array,
          children: { quantity: { type: :integer } }
        }
      }
      
      # Different root arrays - incompatible
      expr = call(:multiply,
        input_elem_ref([:products, :price]),
        input_elem_ref([:orders, :quantity])
      )
      
      metadata = analyze_expression(input_meta, [attr(:invalid, expr)])
      dimension_info = metadata[:invalid][:vectorization][:dimension_info]
      
      expect(dimension_info).to include(
        compatible: false,
        mode: :incompatible
      )
      expect(dimension_info[:all_dimensions]).to contain_exactly([:products], [:orders])
    end

    it "detects incompatible sibling branches at same level" do
      input_meta = {
        company: {
          type: :array,
          children: {
            sales_teams: {
              type: :array,
              children: { revenue: { type: :float } }
            },
            dev_teams: {
              type: :array,
              children: { velocity: { type: :integer } }
            }
          }
        }
      }
      
      # Sibling arrays at same nesting level - incompatible
      expr = call(:add,
        input_elem_ref([:company, :sales_teams, :revenue]),
        input_elem_ref([:company, :dev_teams, :velocity])
      )
      
      metadata = analyze_expression(input_meta, [attr(:mixed, expr)])
      dimension_info = metadata[:mixed][:vectorization][:dimension_info]
      
      expect(dimension_info).to include(
        compatible: false,
        mode: :incompatible
      )
    end
  end

  describe "complex hierarchical validation" do
    let(:complex_input_meta) do
      {
        organizations: {
          type: :array,
          children: {
            budget: { type: :float },
            regions: {
              type: :array,
              children: {
                target: { type: :float },
                offices: {
                  type: :array,
                  children: {
                    staff_count: { type: :integer },
                    teams: {
                      type: :array,
                      children: { 
                        performance: { type: :float },
                        members: {
                          type: :array,
                          children: { rating: { type: :float } }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    end

    it "validates deep hierarchical compatibility" do
      # teams.members.rating vs organizations.budget (5-level to 1-level)
      expr = call(:>,
        input_elem_ref([:organizations, :regions, :offices, :teams, :members, :rating]),
        input_elem_ref([:organizations, :budget])
      )
      
      metadata = analyze_expression(complex_input_meta, [attr(:rating_vs_budget, expr)])
      dimension_info = metadata[:rating_vs_budget][:vectorization][:dimension_info]
      
      expect(dimension_info).to include(
        compatible: true,
        mode: :hierarchical
      )
      expect(dimension_info[:primary_dimension]).to eq([:organizations, :regions, :offices, :teams, :members])
      expect(dimension_info[:all_dimensions]).to include(
        [:organizations],
        [:organizations, :regions, :offices, :teams, :members]
      )
    end

    it "validates multi-level hierarchical compatibility" do
      # teams.performance vs regions.target (4-level to 2-level)
      expr = call(:>=,
        input_elem_ref([:organizations, :regions, :offices, :teams, :performance]),
        input_elem_ref([:organizations, :regions, :target])
      )
      
      metadata = analyze_expression(complex_input_meta, [attr(:meets_target, expr)])
      dimension_info = metadata[:meets_target][:vectorization][:dimension_info]
      
      expect(dimension_info).to include(
        compatible: true,
        mode: :hierarchical
      )
      expect(dimension_info[:all_dimensions]).to contain_exactly(
        [:organizations, :regions],
        [:organizations, :regions, :offices, :teams]
      )
    end
  end

  describe "edge cases" do
    it "handles scalar operations (no dimensions)" do
      expr = call(:add, lit(1), lit(2))
      metadata = analyze_expression({}, [attr(:sum, expr)])
      
      # Should not have dimension info for scalar operations
      expect(metadata[:sum][:vectorization]).to be_nil
    end

    it "handles single array operand" do
      input_meta = {
        items: {
          type: :array,
          children: { price: { type: :float } }
        }
      }
      
      expr = call(:multiply, input_elem_ref([:items, :price]), lit(2))
      metadata = analyze_expression(input_meta, [attr(:doubled, expr)])
      dimension_info = metadata[:doubled][:vectorization][:dimension_info]
      
      expect(dimension_info).to include(
        compatible: true,
        mode: :same_level,
        primary_dimension: [:items]
      )
    end

    it "handles empty dimensions list" do
      # This shouldn't happen in normal usage, but test the helper method
      detector = NewBroadcastDetector.new(nil, state)
      result = detector.send(:check_dimension_compatibility, [])
      
      expect(result).to include(
        compatible: true,
        mode: :scalar
      )
    end

    it "handles single dimension in list" do
      detector = NewBroadcastDetector.new(nil, state)
      result = detector.send(:check_dimension_compatibility, [[:items]])
      
      expect(result).to include(
        compatible: true,
        mode: :same_level,
        primary_dimension: [:items]
      )
    end
  end

  describe "dimension extraction" do
    it "extracts dimensions from array references" do
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
      
      expr = input_elem_ref([:regions, :offices, :revenue])
      metadata = analyze_expression(input_meta, [attr(:revenues, expr)])
      
      expect(metadata[:revenues][:array_source][:dimensions]).to eq([:regions, :offices])
    end

    it "extracts dimensions from vectorized operations" do
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
        input_elem_ref([:items, :price]),
        input_elem_ref([:items, :quantity])
      )
      
      metadata = analyze_expression(input_meta, [attr(:subtotals, expr)])
      
      # Should extract dimensions from the vectorized operation
      detector = NewBroadcastDetector.new(nil, state)
      dimensions = detector.send(:extract_dimensions, metadata[:subtotals])
      
      expect(dimensions).to eq([:items])
    end
  end
end