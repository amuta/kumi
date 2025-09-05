# frozen_string_literal: true

module Kumi
  module Core
    module FunctionRegistry
      # Logical operations and boolean functions
      module LogicalFunctions
        def self.element_wise_and(a, b)
          if ENV["DEBUG_CASCADE"]
            puts "DEBUG element_wise_and called with:"
            puts "  a: #{a.inspect} (depth: #{array_depth(a)})"
            puts "  b: #{b.inspect} (depth: #{array_depth(b)})"
          end

          case [a.class, b.class]
          when [Array, Array]
            # Both are arrays - handle hierarchical broadcasting
            if hierarchical_broadcasting_needed?(a, b)
              puts "  -> Using hierarchical broadcasting" if ENV["DEBUG_CASCADE"]
              result = perform_hierarchical_and(a, b)
              puts "  -> Hierarchical result: #{result.inspect}" if ENV["DEBUG_CASCADE"]
            else
              # Same structure - use zip for element-wise operations
              puts "  -> Using same-structure zip" if ENV["DEBUG_CASCADE"]
              result = a.zip(b).map { |elem_a, elem_b| element_wise_and(elem_a, elem_b) }
              puts "  -> Zip result: #{result.inspect}" if ENV["DEBUG_CASCADE"]
            end
            result
          when [Array, Object], [Object, Array]
            # One is array, one is scalar - broadcast scalar
            puts "  -> Broadcasting scalar to array" if ENV["DEBUG_CASCADE"]
            result = if a.is_a?(Array)
                       a.map { |elem| element_wise_and(elem, b) }
                     else
                       b.map { |elem| element_wise_and(a, elem) }
                     end
            puts "  -> Broadcast result: #{result.inspect}" if ENV["DEBUG_CASCADE"]
            result
          else
            # Both are scalars - simple AND
            puts "  -> Simple scalar AND: #{a} && #{b} = #{a && b}" if ENV["DEBUG_CASCADE"]
            a && b
          end
        end

        def self.hierarchical_broadcasting_needed?(a, b)
          # Check if arrays have different nesting depths (hierarchical broadcasting)
          depth_a = array_depth(a)
          depth_b = array_depth(b)
          depth_a != depth_b
        end

        def self.array_depth(arr)
          return 0 unless arr.is_a?(Array)
          return 1 if arr.empty? || !arr.first.is_a?(Array)

          1 + array_depth(arr.first)
        end

        def self.perform_hierarchical_and(a, b)
          # Determine which is the higher dimension and which is lower
          depth_a = array_depth(a)
          depth_b = array_depth(b)

          puts "    perform_hierarchical_and: depth_a=#{depth_a}, depth_b=#{depth_b}" if ENV["DEBUG_CASCADE"]

          if depth_a > depth_b
            # a is deeper (child level), b is shallower (parent level)
            # Broadcast b values to match a's structure - PRESERVE a's structure
            puts "    -> Broadcasting b (parent) to match a (child) structure" if ENV["DEBUG_CASCADE"]
            broadcast_parent_to_child_structure(a, b)
          else
            # b is deeper (child level), a is shallower (parent level)
            # Broadcast a values to match b's structure - PRESERVE b's structure
            puts "    -> Broadcasting a (parent) to match b (child) structure" if ENV["DEBUG_CASCADE"]
            broadcast_parent_to_child_structure(b, a)
          end
        end

        def self.broadcast_parent_to_child_structure(child_array, parent_array)
          # Broadcast parent array values to match child array structure, preserving child structure
          if ENV["DEBUG_CASCADE"]
            puts "      broadcast_parent_to_child_structure:"
            puts "        child_array: #{child_array.inspect}"
            puts "        parent_array: #{parent_array.inspect}"
            puts "        child depth: #{array_depth(child_array)}, parent depth: #{array_depth(parent_array)}"
          end

          # Use child array structure as template and broadcast parent values
          map_with_parent_broadcasting(child_array, parent_array, [])
        end

        def self.map_with_parent_broadcasting(child_structure, parent_structure, indices)
          if child_structure.is_a?(Array)
            child_structure.map.with_index do |child_elem, index|
              new_indices = indices + [index]

              # Navigate parent structure with fewer indices (broadcasting)
              parent_depth = array_depth(parent_structure)
              parent_indices = new_indices[0, parent_depth]
              parent_value = navigate_indices(parent_structure, parent_indices)

              if child_elem.is_a?(Array)
                # Recurse deeper into child structure
                map_with_parent_broadcasting(child_elem, parent_structure, new_indices)
              else
                # Leaf level - apply AND operation
                result = child_elem && parent_value
                if ENV["DEBUG_CASCADE"]
                  puts "          Leaf: child=#{child_elem}, parent=#{parent_value} (indices #{new_indices.inspect}) -> #{result}"
                end
                result
              end
            end
          else
            # Non-array child - just AND with parent
            child_structure && parent_structure
          end
        end

        def self.navigate_indices(structure, indices)
          return structure if indices.empty?
          return structure unless structure.is_a?(Array)
          return nil if indices.first >= structure.length

          navigate_indices(structure[indices.first], indices[1..])
        end

        def self.broadcast_to_match_structure(child_array, parent_array)
          # Legacy method - keeping for backward compatibility
          if ENV["DEBUG_CASCADE"]
            puts "      broadcast_to_match_structure (LEGACY):"
            puts "        child_array: #{child_array.inspect}"
            puts "        parent_array: #{parent_array.inspect}"
            puts "        child_array.length: #{child_array.length}"
            puts "        parent_array.length: #{parent_array.length}"
          end

          result = child_array.zip(parent_array).map do |child_elem, parent_elem|
            puts "        Combining child_elem: #{child_elem.inspect} with parent_elem: #{parent_elem.inspect}" if ENV["DEBUG_CASCADE"]
            element_wise_and(child_elem, parent_elem)
          end

          puts "        broadcast result: #{result.inspect}" if ENV["DEBUG_CASCADE"]
          result
        end

        def self.definitions
          {
            # Basic logical operations
            and: FunctionBuilder::Entry.new(
              fn: ->(*conditions) { conditions.all? },
              arity: -1,
              param_types: [:boolean],
              return_type: :boolean,
              description: "Logical AND of multiple conditions"
            ),

            or: FunctionBuilder::Entry.new(
              fn: ->(*conditions) { conditions.any? },
              arity: -1,
              param_types: [:boolean],
              return_type: :boolean,
              description: "Logical OR of multiple conditions"
            ),

            not: FunctionBuilder::Entry.new(
              fn: lambda(&:!),
              arity: 1,
              param_types: [:boolean],
              return_type: :boolean,
              description: "Logical NOT"
            ),

            # Collection logical operations
            all?: FunctionBuilder.collection_unary(:all?, "Check if all elements in collection are truthy", :all?, reducer: true),
            any?: FunctionBuilder.collection_unary(:any?, "Check if any element in collection is truthy", :any?, reducer: true),
            none?: FunctionBuilder.collection_unary(:none?, "Check if no elements in collection are truthy", :none?, reducer: true),

            # Element-wise AND for cascades - works on arrays with same structure
            cascade_and: FunctionBuilder::Entry.new(
              fn: lambda do |*conditions|
                if ENV["DEBUG_CASCADE"]
                  puts "DEBUG cascade_and called with #{conditions.length} conditions:"
                  conditions.each_with_index do |cond, i|
                    puts "  condition[#{i}]: #{cond.inspect}"
                  end
                end

                return false if conditions.empty?

                # Always process uniformly, even for single conditions
                # This ensures DeclarationReferences are evaluated properly
                result = conditions.first
                conditions[1..].each_with_index do |condition, i|
                  puts "  Combining result with condition[#{i + 1}]" if ENV["DEBUG_CASCADE"]
                  result = LogicalFunctions.element_wise_and(result, condition)
                  puts "  Result after combining: #{result.inspect}" if ENV["DEBUG_CASCADE"]
                end

                puts "  Final cascade_and result: #{result.inspect}" if ENV["DEBUG_CASCADE"]
                result
              end,
              arity: -1,
              param_types: [:boolean],
              return_type: :boolean,
              description: "Element-wise AND for arrays with same nested structure"
            ),

            # Conditional selection (ternary operator)
            select: FunctionBuilder::Entry.new(
              fn: lambda do |condition, value_when_true, value_when_false|
                condition ? value_when_true : value_when_false
              end,
              arity: 3,
              param_types: %i[boolean any any],
              return_type: :any,
              description: "Select value based on condition (ternary operator)"
            )
          }
        end
      end
    end
  end
end
