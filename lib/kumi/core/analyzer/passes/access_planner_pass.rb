# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        # RESPONSIBILITY: Create access plans for input fields based on input metadata
        # DEPENDENCIES: :inputs - Hash of input field metadata from InputCollector
        # PRODUCES: :input_access_plans - Hash mapping field paths to access operation plans
        # INTERFACE: new(schema, state).run(errors)
        class AccessPlannerPass < PassBase
          def run(errors)
            input_metadata = get_state(:inputs)
            access_plans = {}

            input_metadata.each do |field_name, field_meta|
              plan_field_access(field_name, field_meta, [field_name], access_plans)
            end

            state.with(:input_access_plans, access_plans.freeze)
          end

          private

          def plan_field_access(field_name, field_meta, current_path, access_plans)
            path_key = current_path.join(".")
            access_plans[path_key] = build_access_plans(current_path, field_meta)

            # Recursively plan for children
            return unless field_meta[:children]

            field_meta[:children].each do |child_name, child_meta|
              child_path = current_path + [child_name]
              plan_field_access(child_name, child_meta, child_path, access_plans)
            end
          end

          def build_access_plans(path, field_meta)
            {
              structure: { type: :structure, path: path, operations: build_operations(path, field_meta) },
              element: { type: :element, path: path, operations: build_operations(path, field_meta) },
              flattened: { type: :flattened, path: path, operations: build_operations(path, field_meta, flattened: true) }
            }
          end

          def build_operations(path, field_meta, flattened: false)
            operations = []
            # The top-level data context is always an object/hash
            parent_access_mode = :object
            current_children_meta = get_state(:inputs)

            path.each do |segment|
              # Find the metadata for the current segment
              segment_meta = current_children_meta[segment]
              break unless segment_meta # Path is invalid, stop planning

              # If the parent was an object, we need to enter this segment by its key
              operations << { type: :enter_hash, key: segment } if parent_access_mode == :object

              # If this segment is an array, we need to enter it to access its children
              operations << { type: :enter_array } if segment_meta[:type] == :array

              # The access mode of the current segment determines how we'll access its children
              parent_access_mode = segment_meta[:access_mode] || :object
              current_children_meta = segment_meta[:children] || {}
            end

            operations
          end
        end
      end
    end
  end
end
