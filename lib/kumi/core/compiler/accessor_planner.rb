# frozen_string_literal: true

module Kumi
  module Core
    module Compiler
      # Analyzes input metadata and creates access plans for different use cases
      # Returns data structures that describe HOW to access data, not the actual lambdas
      class AccessorPlanner
        def self.plan(input_metadata)
          new(input_metadata).plan
        end

        def initialize(input_metadata)
          @input_metadata = input_metadata
          @plans = {}
        end

        def plan
          @input_metadata.each do |field_name, field_meta|
            plan_field_access(field_name, field_meta, [field_name])
          end

          @plans.freeze
        end

        private

        def plan_field_access(field_name, field_meta, current_path)
          path_key = current_path.join(".")
          @plans[path_key] = build_access_plans(current_path)

          # Recursively plan for children
          return unless field_meta[:children]

          field_meta[:children].each do |child_name, child_meta|
            child_path = current_path + [child_name]
            plan_field_access(child_name, child_meta, child_path)
          end
        end

        def build_access_plans(path)
          {
            structure: { type: :structure, path: path, operations: build_operations(path) },
            element: { type: :element, path: path, operations: build_operations(path) },
            flattened: { type: :flattened, path: path, operations: build_operations(path, flattened: true) }
          }
        end

        def build_operations(path, flattened: false)
          operations = []
          # The top-level data context is always an object/hash
          parent_access_mode = :object
          current_children_meta = @input_metadata

          path.each do |segment|
            # Find the metadata for the current segment
            segment_meta = current_children_meta[segment]
            break unless segment_meta # Path is invalid, stop planning

            # If the parent was an object, we need to enter this segment by its key
            operations << { type: :enter_object, key: segment } if parent_access_mode == :object

            # If this segment is an array, we need to enter it to access its children
            operations << { type: :enter_array } if segment_meta[:type] == :array

            # The access mode of the current segment determines how we'll access its children
            parent_access_mode = segment_meta[:access_mode] || :object
            current_children_meta = segment_meta[:children] || {}
          end

          # Add the final flatten operation if required
          operations << { type: :flatten } if flattened

          operations
        end
      end
    end
  end
end
