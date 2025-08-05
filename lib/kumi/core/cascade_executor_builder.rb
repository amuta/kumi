# frozen_string_literal: true

module Kumi
  module Core
    # Builds cascade execution lambdas from analysis metadata
    class CascadeExecutorBuilder
      include NestedStructureUtils

      def self.build_executor(strategy, analysis_state)
        new(strategy, analysis_state).build
      end

      def initialize(strategy, analysis_state)
        @strategy = strategy
        @analysis_state = analysis_state
      end

      def build
        case @strategy[:mode]
        when :hierarchical
          build_hierarchical_executor
        when :nested_array, :deep_nested_array
          build_nested_array_executor
        when :simple_array
          build_simple_array_executor
        else
          build_scalar_executor
        end
      end

      private

      def build_hierarchical_executor
        lambda do |cond_results, res_results, base_result, pairs|
          # Find the result structure to use as template (deepest structure)
          all_values = (res_results + cond_results + [base_result].compact).select { |v| v.is_a?(Array) }
          result_template = all_values.max_by { |v| calculate_array_depth(v) }

          return execute_scalar_cascade(cond_results, res_results, base_result, pairs) unless result_template

          # Apply hierarchical cascade logic using the result structure as template
          map_nested_structure(result_template) do |*indices|
            result = nil

            # Check conditional cases first with hierarchical broadcasting for conditions
            pairs.each_with_index do |(_cond, _res), pair_idx|
              cond_val = navigate_with_hierarchical_broadcasting(cond_results[pair_idx], indices, result_template)
              next unless cond_val

              res_val = navigate_nested_indices(res_results[pair_idx], indices)
              result = res_val
              break
            end

            # If no conditional case matched, use base case
            result = navigate_nested_indices(base_result, indices) if result.nil? && base_result

            result
          end
        end
      end

      def build_nested_array_executor
        lambda do |cond_results, res_results, base_result, pairs|
          # For nested arrays, we need to find the structure template
          structure_template = find_structure_template(cond_results + res_results + [base_result].compact)
          return execute_scalar_cascade(cond_results, res_results, base_result, pairs) unless structure_template

          # Apply cascade logic recursively through the nested structure
          map_nested_structure(structure_template) do |*indices|
            result = nil

            # Check conditional cases first
            pairs.each_with_index do |(_cond, _res), pair_idx|
              cond_val = navigate_nested_indices(cond_results[pair_idx], indices)
              next unless cond_val

              res_val = navigate_nested_indices(res_results[pair_idx], indices)
              result = res_val
              break
            end

            # If no conditional case matched, use base case
            result = navigate_nested_indices(base_result, indices) if result.nil? && base_result

            result
          end
        end
      end

      def build_simple_array_executor
        lambda do |cond_results, res_results, base_result, pairs|
          array_length = determine_array_length(cond_results + res_results + [base_result].compact)

          (0...array_length).map do |i|
            result = nil
            # Check conditional cases first
            pairs.each_with_index do |(_cond, _res), pair_idx|
              cond_val = extract_element_at_index(cond_results[pair_idx], i)
              next unless cond_val

              res_val = extract_element_at_index(res_results[pair_idx], i)
              result = res_val
              break
            end

            # If no conditional case matched, use base case
            result = extract_element_at_index(base_result, i) if result.nil? && base_result

            result
          end
        end
      end

      def build_scalar_executor
        lambda do |cond_results, res_results, base_result, pairs|
          pairs.each_with_index do |(_cond, _res), pair_idx|
            return res_results[pair_idx] if cond_results[pair_idx]
          end
          base_result
        end
      end

      def execute_scalar_cascade(cond_results, res_results, base_result, pairs)
        pairs.each_with_index do |(_cond, _res), pair_idx|
          return res_results[pair_idx] if cond_results[pair_idx]
        end
        base_result
      end
    end
  end
end
