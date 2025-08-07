# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kumi::Core::Analyzer::DimensionalResolver do
  # Create a simple mock for DependencyEdge
  let(:edge_class) do
    Struct.new(:to, :type, :via, :conditional, :cascade_owner, keyword_init: true)
  end

  let(:input_metadata) do
    {
      regions: {
        type: :array,
        children: {
          offices: {
            type: :array,
            children: {
              office_multiplier: { type: :float },
              teams: {
                type: :array,
                children: {
                  performance_score: { type: :float },
                  employees: {
                    type: :array,
                    children: {
                      salary: { type: :float },
                      rating: { type: :float },
                      level: { type: :string }
                    }
                  }
                }
              }
            }
          }
        }
      },
      company_name: { type: :string }
    }
  end

  describe ".analyze_all" do
    it "analyzes all declarations and returns execution contexts" do
      dependency_graph = {
        employee_bonus: [
          edge_class.new(to: :high_performer, type: :ref, via: :cascade_and),
          edge_class.new(to: :senior_level, type: :ref, via: :cascade_and),
          edge_class.new(to: :top_team, type: :ref, via: :cascade_and),
          edge_class.new(to: :regions, type: :key, via: :multiply)
        ],
        salaries: [
          edge_class.new(to: :office_has_multiplier, type: :ref, via: :cascade_and),
          edge_class.new(to: :regions, type: :key, via: :multiply)
        ],
        company_info: [
          edge_class.new(to: :company_name, type: :key, via: :==)
        ],
        constant_value: []  # No dependencies
      }
      
      result = described_class.analyze_all(dependency_graph, input_metadata)
      
      expect(result).to eq({
        employee_bonus: {
          dimension: [:regions, :offices, :teams, :employees],
          depth: 4
        },
        salaries: {
          dimension: [:regions, :offices, :teams, :employees],
          depth: 4
        },
        company_info: {
          dimension: [],
          depth: 0
        },
        constant_value: {
          dimension: [],
          depth: 0
        }
      })
    end
  end

  describe ".analyze_declaration" do
    it "analyzes employee_bonus dependencies correctly" do
      # These would come from the DependencyResolver for employee_bonus
      dependencies = [
        edge_class.new(to: :high_performer, type: :ref, via: :cascade_and),
        edge_class.new(to: :senior_level, type: :ref, via: :cascade_and),
        edge_class.new(to: :top_team, type: :ref, via: :cascade_and),
        edge_class.new(to: :regions, type: :key, via: :multiply),
        edge_class.new(to: :high_performer, type: :ref, via: :cascade_and),
        edge_class.new(to: :top_team, type: :ref, via: :cascade_and),
        edge_class.new(to: :regions, type: :key, via: :multiply),
        edge_class.new(to: :regions, type: :key, via: :multiply)
      ]
      
      result = described_class.analyze_declaration(dependencies, input_metadata)
      
      # Should find regions as the only input dependency and traverse to deepest array
      expect(result).to eq({
        dimension: [:regions, :offices, :teams, :employees],
        depth: 4
      })
    end

    it "analyzes salaries dependencies correctly" do
      # These would come from the DependencyResolver for salaries
      dependencies = [
        edge_class.new(to: :office_has_multiplier, type: :ref, via: :cascade_and),
        edge_class.new(to: :regions, type: :key, via: :multiply),
        edge_class.new(to: :regions, type: :key, via: :multiply),
        edge_class.new(to: :regions, type: :key, via: nil)
      ]
      
      result = described_class.analyze_declaration(dependencies, input_metadata)
      
      # Should find regions and traverse to deepest array path
      expect(result).to eq({
        dimension: [:regions, :offices, :teams, :employees],
        depth: 4
      })
    end

    it "handles dependencies with only references (no input fields)" do
      dependencies = [
        edge_class.new(to: :some_trait, type: :ref, via: :cascade_and),
        edge_class.new(to: :another_trait, type: :ref, via: :multiply)
      ]
      
      result = described_class.analyze_declaration(dependencies, input_metadata)
      
      # No input dependencies, so depth 0
      expect(result).to eq({
        dimension: [],
        depth: 0
      })
    end

    it "handles mixed scalar and array input dependencies" do
      dependencies = [
        edge_class.new(to: :company_name, type: :key, via: :==),
        edge_class.new(to: :regions, type: :key, via: :multiply)
      ]
      
      result = described_class.analyze_declaration(dependencies, input_metadata)
      
      # Should use the deepest (regions), ignore scalar (company_name)
      expect(result).to eq({
        dimension: [:regions, :offices, :teams, :employees],
        depth: 4
      })
    end

    it "correctly identifies conditional dependencies" do
      dependencies = [
        edge_class.new(to: :regions, type: :key, via: :multiply, conditional: true, cascade_owner: :some_value),
        edge_class.new(to: :regions, type: :key, via: :add, conditional: false)
      ]
      
      result = described_class.analyze_declaration(dependencies, input_metadata)
      
      # Conditional flag doesn't affect dimension analysis
      expect(result).to eq({
        dimension: [:regions, :offices, :teams, :employees],
        depth: 4
      })
    end
  end
end