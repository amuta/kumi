# frozen_string_literal: true

require_relative '../../../../../lib/kumi/core/analyzer/passes/new_broadcast_detector'

RSpec.describe NewBroadcastDetector, "hierarchical broadcasting" do
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

  describe "nested array structures" do
    let(:hierarchical_input_meta) do
      {
        regions: {
          type: :array,
          children: {
            name: { type: :string },
            target: { type: :float },
            offices: {
              type: :array,
              children: {
                name: { type: :string },
                budget: { type: :float },
                teams: {
                  type: :array,
                  children: {
                    name: { type: :string },
                    performance: { type: :float }
                  }
                }
              }
            }
          }
        }
      }
    end

    it "detects hierarchical broadcasting from teams to offices" do
      # teams.performance > offices.budget (3-level to 2-level)
      expr = call(:>,
        input_elem_ref([:regions, :offices, :teams, :performance]),
        input_elem_ref([:regions, :offices, :budget])
      )
      
      metadata = analyze_expression(hierarchical_input_meta, [attr(:teams_exceed_budget, expr)])
      result = metadata[:teams_exceed_budget]
      
      expect(result[:operation_type]).to eq(:vectorized)
      expect(result[:vectorization][:strategy]).to eq(:broadcast_scalar)
      
      dimension_info = result[:vectorization][:dimension_info]
      expect(dimension_info).to include(
        compatible: true,
        mode: :hierarchical,
        primary_dimension: [:regions, :offices, :teams]
      )
      expect(dimension_info[:all_dimensions]).to contain_exactly(
        [:regions, :offices],
        [:regions, :offices, :teams]
      )
      
      expect(result[:compilation][:requires_hierarchical_logic]).to eq(true)
    end

    it "detects same-level broadcasting" do
      # teams.performance vs teams.name (same level)
      expr = call(:!=,
        input_elem_ref([:regions, :offices, :teams, :performance]),
        input_elem_ref([:regions, :offices, :teams, :name])
      )
      
      metadata = analyze_expression(hierarchical_input_meta, [attr(:comparison, expr)])
      result = metadata[:comparison]
      
      dimension_info = result[:vectorization][:dimension_info]
      expect(dimension_info).to include(
        compatible: true,
        mode: :same_level,
        primary_dimension: [:regions, :offices, :teams]
      )
      
      expect(result[:compilation][:requires_hierarchical_logic]).to eq(false)
    end

    it "detects incompatible dimensions" do
      # Different root arrays - should be incompatible
      input_meta = {
        products: {
          type: :array,
          children: { price: { type: :float } }
        },
        customers: {
          type: :array,
          children: { age: { type: :integer } }
        }
      }
      
      expr = call(:add,
        input_elem_ref([:products, :price]),
        input_elem_ref([:customers, :age])
      )
      
      metadata = analyze_expression(input_meta, [attr(:invalid, expr)])
      result = metadata[:invalid]
      
      # Should still produce metadata but mark as incompatible
      dimension_info = result[:vectorization][:dimension_info]
      expect(dimension_info[:compatible]).to eq(false)
      expect(dimension_info[:mode]).to eq(:incompatible)
    end
  end

  describe "access mode tracking" do
    let(:element_access_input_meta) do
      {
        matrix: {
          type: :array,
          access_mode: :element,
          children: {
            row: {
              type: :array,
              children: { value: { type: :float } }
            }
          }
        }
      }
    end

    it "tracks element access mode" do
      expr = input_elem_ref([:matrix, :row, :value])
      metadata = analyze_expression(element_access_input_meta, [attr(:values, expr)])
      
      expect(metadata[:values][:array_source][:access_mode]).to eq(:element)
    end

    it "defaults to object access mode" do
      input_meta = {
        items: {
          type: :array,
          children: { price: { type: :float } }
        }
      }
      
      expr = input_elem_ref([:items, :price])
      metadata = analyze_expression(input_meta, [attr(:prices, expr)])
      
      expect(metadata[:prices][:array_source][:access_mode]).to eq(:object)
    end
  end

  describe "depth calculation" do
    it "calculates depth for nested structures" do
      input_meta = {
        level1: {
          type: :array,
          children: {
            level2: {
              type: :array,
              children: {
                level3: {
                  type: :array,
                  children: { value: { type: :float } }
                }
              }
            }
          }
        }
      }
      
      expr = input_elem_ref([:level1, :level2, :level3, :value])
      metadata = analyze_expression(input_meta, [attr(:deep_values, expr)])
      
      expect(metadata[:deep_values][:array_source]).to include(
        depth: 3,
        dimensions: [:level1, :level2, :level3]
      )
    end
  end

  describe "hierarchical cascade operations" do
    let(:hierarchical_input_meta) do
      {
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
    end

    it "detects hierarchical cascade strategy" do
      # offices.performance > regions.target (hierarchical comparison)
      trait_expr = call(:>,
        input_elem_ref([:regions, :offices, :performance]),
        input_elem_ref([:regions, :target])
      )
      trait_decl = trait(:exceeds_regional_target, trait_expr)
      
      cascade_expression = syntax(:cascade_expr, [
        syntax(:case_expr, ref(:exceeds_regional_target), lit("Excellent"), loc: nil),
        syntax(:case_expr, lit(true), lit("Needs Improvement"), loc: nil)
      ], loc: nil)
      
      metadata = analyze_expression(hierarchical_input_meta, [
        trait_decl, 
        attr(:office_rating, cascade_expression)
      ])
      result = metadata[:office_rating]
      
      expect(result[:operation_type]).to eq(:vectorized)
      expect(result[:cascade][:processing][:strategy]).to eq(:hierarchical_broadcast)
      expect(result[:compilation][:requires_hierarchical_logic]).to eq(true)
      
      dimension_info = result[:vectorization][:dimension_info]
      expect(dimension_info[:mode]).to eq(:hierarchical)
    end
  end

  describe "compilation requirements" do
    let(:hierarchical_input_meta) do
      {
        regions: {
          type: :array,
          children: {
            offices: {
              type: :array,
              children: {
                teams: {
                  type: :array,
                  children: { score: { type: :float } }
                }
              }
            }
          }
        }
      }
    end

    it "sets hierarchical requirements for multi-level operations" do
      expr = call(:sum, input_elem_ref([:regions, :offices, :teams, :score]))
      metadata = analyze_expression(hierarchical_input_meta, [attr(:total_score, expr)])
      
      expect(metadata[:total_score][:compilation]).to include(
        requires_flattening: true,
        requires_hierarchical_logic: false  # Reduction flattens everything
      )
      expect(metadata[:total_score][:reduction][:input][:flatten_depth]).to eq(:all)
    end

    it "sets dimension check requirements for mixed operations" do
      # Mix different dimensional levels
      expr = call(:add,
        input_elem_ref([:regions, :offices, :teams, :score]),
        input_elem_ref([:regions, :offices, :teams, :score])  # Same level - no dimension check needed
      )
      
      metadata = analyze_expression(hierarchical_input_meta, [attr(:doubled_score, expr)])
      
      expect(metadata[:doubled_score][:compilation][:requires_dimension_check]).to eq(false)
    end
  end
end