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
          path_key = current_path.join('.')
          
          # Build access plans for this path
          @plans[path_key] = build_access_plans(current_path, field_meta)
          
          # Recursively plan for children
          if field_meta[:children]
            field_meta[:children].each do |child_name, child_meta|
              child_path = current_path + [child_name]
              plan_field_access(child_name, child_meta, child_path)
            end
          end
        end

        def build_access_plans(path, final_meta)
          plans = {}
          
          # Build all 3 types - let analyzer catch bad references
          plans[:structure] = build_plan(path, :structure)
          plans[:element] = build_plan(path, :element) 
          plans[:flattened] = build_plan(path, :flattened)
          
          plans
        end

        def build_plan(path, access_type)
          {
            type: access_type,
            path: path,
            operations: build_operations(path, access_type)
          }
        end

        def build_operations(path, access_type)
          operations = []
          current_meta = @input_metadata
          
          path.each do |segment|
            segment_meta = current_meta[segment]
            
            # Fetch the field
            operations << { 
              type: :fetch, 
              key: segment
            }
            
            # If it's an array, set up iteration context
            if segment_meta[:type] == :array
              operations << { 
                type: :enter_array,
                access_mode: segment_meta[:access_mode] || :object
              }
            end
            
            current_meta = segment_meta[:children] if segment_meta[:children]
          end
          
          # Add final operation based on access type
          case access_type
          when :flattened
            operations << { type: :flatten }
          end
          
          operations
        end
      end
    end
  end
end