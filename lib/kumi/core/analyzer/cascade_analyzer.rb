# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      # Handles cascade expression analysis for broadcast detection
      class CascadeAnalysis
        def initialize(broadcast_detector)
          @broadcast_detector = broadcast_detector
        end

        def analyze_cascade_expression(expr)
          # Analyze each case's result expression
          case_analyses = expr.cases.map { |cascade_case| analyze_cascade_case(cascade_case) }
          
          # Determine if any result is element-wise
          has_element_wise_results = case_analyses.any? { |analysis| analysis[:is_element_wise] }
          
          # Enable element-wise cascades when any result is element-wise
          if has_element_wise_results
            validate_cascade_dimension_compatibility(case_analyses)
            
            {
              operation_type: :element_wise,
              cascade_type: :mixed_results,
              case_analyses: case_analyses
            }
          else
            # All cascades treated as scalar for now
            {
              operation_type: :scalar,
              cascade_type: has_element_wise_results ? :mixed_results : :all_scalar,
              case_analyses: case_analyses,
              # Store analysis for future use
              _detected_element_wise: has_element_wise_results
            }
          end
        end

        private

        def analyze_cascade_case(cascade_case)
          # cascade_case is from AST, result is AST node
          result_expr = cascade_case.result
          
          # Analyze the result expression to determine if it's element-wise
          case result_expr
          when Kumi::Syntax::CallExpression
            # Use the broadcast detector's call expression analysis
            result_metadata = @broadcast_detector.send(:analyze_call_expression_for_cascade, result_expr)
            {
              is_element_wise: result_metadata[:operation_type] == :element_wise,
              metadata: result_metadata,
              expression: result_expr
            }
          when Kumi::Syntax::Literal
            {
              is_element_wise: false,
              metadata: { operation_type: :scalar },
              expression: result_expr
            }
          when Kumi::Syntax::DeclarationReference
            # Look up the referenced declaration's type
            decl_name = result_expr.name
            decl_metadata = @broadcast_detector.instance_variable_get(:@metadata)[decl_name]
            is_element_wise = decl_metadata && decl_metadata[:operation_type] == :element_wise
            
            {
              is_element_wise: is_element_wise,
              metadata: decl_metadata || { operation_type: :scalar },
              expression: result_expr
            }
          else
            # Default to scalar for unknown expression types
            {
              is_element_wise: false,
              metadata: { operation_type: :scalar },
              expression: result_expr
            }
          end
        end

        def validate_cascade_dimension_compatibility(case_analyses)
          element_wise_cases = case_analyses.select { |analysis| analysis[:is_element_wise] }
          
          # For now, assume all element-wise results are compatible
          # TODO: Implement dimension validation logic
          # - Check that all element-wise results operate on same input dimensions
          # - Validate that array operations have compatible shapes
          
          return true if element_wise_cases.size <= 1
          
          # Simple validation: check if all element-wise cases reference same input paths
          paths = element_wise_cases.map do |analysis|
            metadata = analysis[:metadata]
            metadata[:operands]&.find { |op| op[:type] == :source }&.dig(:source, :path)
          end.compact
          
          # All element-wise cases should reference compatible dimensions
          unique_paths = paths.uniq
          if unique_paths.size > 1
            # TODO: More sophisticated dimension compatibility checking
            # For now, allow different paths (could be same dimension)
          end
          
          true
        end
      end
    end
  end
end