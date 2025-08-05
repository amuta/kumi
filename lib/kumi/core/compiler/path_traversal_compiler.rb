module Kumi
  module Core
    module Compiler
      module PathTraversalCompiler
        private

        def compile_element_field_reference(expr)
          path = expr.path

          # Check if we have nested paths metadata for this path
          nested_paths = @analysis.state[:broadcasts]&.dig(:nested_paths)
          unless nested_paths && nested_paths[path]
            raise Errors::CompilationError, "Missing nested path metadata for #{path.inspect}. This indicates an analyzer bug."
          end

          # Determine operation mode based on context
          operation_mode = determine_operation_mode_for_path(path)
          path_metadata = nested_paths[path]
          lambda do |ctx|
            traverse_nested_path(ctx, path, operation_mode, path_metadata)
          end

          # ERROR: All nested paths should have metadata from the analyzer
          # If we reach here, it means the BroadcastDetector didn't process this path
        end

        # Metadata-driven nested array traversal using the traversal algorithm from our design
        def traverse_nested_path(data, path, operation_mode, path_metadata = nil)
          access_mode = path_metadata&.dig(:access_mode) || :object

          # Use specialized traversal for element access mode
          result = if access_mode == :element
                     traverse_element_path(data, path, operation_mode)
                   else
                     traverse_path_recursive(data, path, operation_mode, access_mode)
                   end

          # Post-process result based on operation mode
          case operation_mode
          when :flatten
            # Completely flatten nested arrays for aggregation
            flatten_completely(result)
          else
            result
          end
        end

        # Specialized traversal for element access mode
        # In element access, we need to extract the specific field from EvaluationWrapper
        # then apply progressive traversal based on path depth
        def traverse_element_path(data, path, _operation_mode)
          # Handle EvaluationWrapper by extracting the specific field
          if data.is_a?(Core::EvaluationWrapper)
            field_name = path.first
            array_data = data[field_name]

            # Always apply progressive traversal based on path depth
            # This gives us the structure at the correct nesting level for both
            # broadcast operations and structure operations
            if array_data.is_a?(Array) && path.length > 1
              # Flatten exactly (path_depth - 1) levels to get the desired nesting level
              array_data.flatten(path.length - 1)
            else
              array_data
            end
          else
            data
          end
        end

        def traverse_path_recursive(data, path, operation_mode, access_mode = :object, original_path_length = nil)
          # Track original path length to determine traversal depth
          original_path_length ||= path.length
          current_depth = original_path_length - path.length

          return data if path.empty?

          field = path.first
          remaining_path = path[1..]

          if remaining_path.empty?
            # Final field - extract based on operation mode
            case operation_mode
            when :broadcast, :flatten
              # Extract field preserving array structure
              extract_field_preserving_structure(data, field, access_mode, current_depth)
            else
              # Simple field access
              if data.is_a?(Array)
                data.map do |item|
                  access_field(item, field, access_mode, current_depth)
                end
              else
                access_field(data, field, access_mode, current_depth)
              end
            end
          elsif data.is_a?(Array)
            # Intermediate step - traverse deeper
            # Array of items - traverse each item
            data.map do |item|
              traverse_path_recursive(access_field(item, field, access_mode, current_depth), remaining_path, operation_mode, access_mode,
                                      original_path_length)
            end
          else
            # Single item - traverse directly
            traverse_path_recursive(access_field(data, field, access_mode, current_depth), remaining_path, operation_mode, access_mode,
                                    original_path_length)
          end
        end

        def extract_field_preserving_structure(data, field, access_mode = :object, depth = 0)
          if data.is_a?(Array)
            data.map { |item| extract_field_preserving_structure(item, field, access_mode, depth) }
          else
            access_field(data, field, access_mode, depth)
          end
        end

        def access_field(data, field, access_mode, _depth = 0)
          case access_mode
          when :element
            # Element access mode - for nested arrays, we need to traverse one level deeper
            # This enables progressive path traversal like input.cube.layer.row.value
            if data.is_a?(Core::EvaluationWrapper)
              data[field]
            elsif data.is_a?(Array)
              # For element access, flatten one level to traverse deeper into nested structure
              data.flatten(1)
            else
              # If not an array, return as-is (leaf level)
              data
            end
          when :object
            # Object access mode - normal hash/object field access
            data[field]
          else
            # Default to object access
            data[field]
          end
        end

        def flatten_completely(data)
          result = []
          flatten_recursive(data, result)
          result
        end

        def flatten_recursive(data, result)
          if data.is_a?(Array)
            data.each { |item| flatten_recursive(item, result) }
          else
            result << data
          end
        end
      end
    end
  end
end