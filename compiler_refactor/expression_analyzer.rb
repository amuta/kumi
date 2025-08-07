# frozen_string_literal: true

module Kumi
  module Core
    # Analyzes expressions to determine if they need element-wise processing
    # and what broadcast metadata they require
    class ExpressionAnalyzer
      def initialize(broadcast_metadata)
        @broadcast_metadata = broadcast_metadata
      end

      # Takes any expression and returns analysis info
      def analyze_expression(expression)
        case expression
        when Kumi::Syntax::CallExpression
          analyze_call_expression(expression)
        when Kumi::Syntax::DeclarationReference
          analyze_declaration_reference(expression)
        when Kumi::Syntax::InputElementReference
          analyze_input_element_reference(expression)
        when Kumi::Syntax::CascadeExpression
          analyze_cascade_expression(expression)
        when Kumi::Syntax::Literal
          analyze_literal(expression)
        else
          # Default to scalar
          {
            is_element_wise: false,
            broadcast_info: nil,
            dimension_info: nil
          }
        end
      end

      private

      def analyze_call_expression(expression)
        # Check if any operands are element-wise
        operand_analyses = expression.args.map { |arg| analyze_expression(arg) }
        has_element_wise_operands = operand_analyses.any? { |analysis| analysis[:is_element_wise] }

        # Special functions that are always element-wise regardless of operands
        element_wise_functions = [:cascade_and]
        
        if has_element_wise_operands || element_wise_functions.include?(expression.fn_name)
          {
            is_element_wise: true,
            broadcast_info: extract_broadcast_info_from_operands(operand_analyses),
            dimension_info: extract_dimension_info_from_operands(operand_analyses),
            operand_analyses: operand_analyses
          }
        else
          {
            is_element_wise: false,
            broadcast_info: nil,
            dimension_info: nil,
            operand_analyses: operand_analyses
          }
        end
      end

      def analyze_declaration_reference(expression)
        # Look up in broadcast metadata
        decl_metadata = @broadcast_metadata[expression.name]
        if decl_metadata && decl_metadata[:operation_type] == :element_wise
          {
            is_element_wise: true,
            broadcast_info: decl_metadata,
            dimension_info: extract_dimension_from_metadata(decl_metadata)
          }
        else
          {
            is_element_wise: false,
            broadcast_info: nil,
            dimension_info: nil
          }
        end
      end

      def analyze_input_element_reference(expression)
        # Input element references are always element-wise
        {
          is_element_wise: true,
          broadcast_info: {
            access_mode: :element,
            depth: expression.path.length - 1
          },
          dimension_info: {
            depth: expression.path.length - 1,
            access_mode: :element
          }
        }
      end

      def analyze_cascade_expression(expression)
        # Analyze all case results
        case_analyses = expression.cases.map do |cascade_case|
          result_analysis = analyze_expression(cascade_case.result)
          condition_analysis = cascade_case.condition ? analyze_expression(cascade_case.condition) : nil
          
          {
            condition_analysis: condition_analysis,
            result_analysis: result_analysis,
            is_element_wise: result_analysis[:is_element_wise] || 
                           (condition_analysis && condition_analysis[:is_element_wise])
          }
        end

        has_element_wise_cases = case_analyses.any? { |analysis| analysis[:is_element_wise] }

        {
          is_element_wise: has_element_wise_cases,
          broadcast_info: has_element_wise_cases ? extract_cascade_broadcast_info(case_analyses) : nil,
          dimension_info: has_element_wise_cases ? extract_cascade_dimension_info(case_analyses) : nil,
          case_analyses: case_analyses
        }
      end

      def analyze_literal(expression)
        {
          is_element_wise: false,
          broadcast_info: nil,
          dimension_info: nil
        }
      end

      def extract_broadcast_info_from_operands(operand_analyses)
        element_wise_operands = operand_analyses.select { |analysis| analysis[:is_element_wise] }
        return nil if element_wise_operands.empty?

        # Use the first element-wise operand's broadcast info as base
        element_wise_operands.first[:broadcast_info]
      end

      def extract_dimension_info_from_operands(operand_analyses)
        element_wise_operands = operand_analyses.select { |analysis| analysis[:is_element_wise] }
        return nil if element_wise_operands.empty?

        # Use the first element-wise operand's dimension info as base
        element_wise_operands.first[:dimension_info]
      end

      def extract_cascade_broadcast_info(case_analyses)
        element_wise_cases = case_analyses.select { |analysis| analysis[:is_element_wise] }
        return nil if element_wise_cases.empty?

        # Use the first element-wise case's broadcast info
        first_element_wise = element_wise_cases.first
        first_element_wise[:result_analysis][:broadcast_info] || 
        first_element_wise[:condition_analysis]&.dig(:broadcast_info)
      end

      def extract_cascade_dimension_info(case_analyses)
        element_wise_cases = case_analyses.select { |analysis| analysis[:is_element_wise] }
        return nil if element_wise_cases.empty?

        # Use the first element-wise case's dimension info
        first_element_wise = element_wise_cases.first
        first_element_wise[:result_analysis][:dimension_info] || 
        first_element_wise[:condition_analysis]&.dig(:dimension_info)
      end

      def extract_dimension_from_metadata(metadata)
        return nil unless metadata

        if metadata[:case_analyses]
          # Complex metadata from BroadcastDetector
          first_analysis = metadata[:case_analyses].first
          if first_analysis && first_analysis[:metadata]
            {
              depth: first_analysis[:metadata][:depth],
              dimension_mode: first_analysis[:metadata][:dimension_mode],
              access_mode: first_analysis[:metadata][:access_mode]
            }
          end
        else
          # Simple metadata
          {
            depth: metadata[:depth] || 1,
            access_mode: metadata[:access_mode] || :element
          }
        end
      end
    end
  end
end