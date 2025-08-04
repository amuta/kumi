# frozen_string_literal: true

module Kumi
  module Core
    # Shared utilities for working with nested array structures
    module NestedStructureUtils
      def calculate_array_depth(arr)
        return 0 unless arr.is_a?(Array)
        return 1 if arr.empty? || !arr.first.is_a?(Array)

        1 + calculate_array_depth(arr.first)
      end

      def map_nested_structure(structure, indices = [], &block)
        if structure.is_a?(Array) && structure.first.is_a?(Array)
          # Still nested - recurse deeper
          structure.map.with_index do |sub_structure, i|
            map_nested_structure(sub_structure, indices + [i], &block)
          end
        elsif structure.is_a?(Array)
          # Leaf array level - apply function to elements
          structure.map.with_index do |_element, i|
            yield(*(indices + [i]))
          end
        else
          # Single element - apply function
          yield(*indices)
        end
      end

      def navigate_nested_indices(structure, indices)
        indices.reduce(structure) do |current, index|
          if current.is_a?(Array)
            current[index]
          else
            # If we hit a non-array during navigation, it means we're dealing with
            # mixed nesting levels - return the current value
            current
          end
        end
      end

      def navigate_with_hierarchical_broadcasting(value, indices, template)
        # Navigate through value with hierarchical broadcasting to match template structure
        value_depth = calculate_array_depth(value)
        template_depth = calculate_array_depth(template)

        if value_depth < template_depth
          # Value is at parent level - broadcast to child level by using fewer indices
          parent_indices = indices[0, value_depth]
          navigate_nested_indices(value, parent_indices)
        else
          # Same or deeper level - navigate normally
          navigate_nested_indices(value, indices)
        end
      end

      def find_structure_template(all_results)
        # Find the first array to use as structure template
        all_results.find { |v| v.is_a?(Array) }
      end

      def determine_array_length(arrays)
        # Find the first array and use its length
        first_array = arrays.find { |v| v.is_a?(Array) }
        first_array ? first_array.length : 1
      end

      def extract_element_at_index(value, index)
        if value.is_a?(Array)
          index < value.length ? value[index] : nil
        else
          value # Scalar value - same for all indices
        end
      end
    end
  end
end