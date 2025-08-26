# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        # Creates an index table from access_plans for fast NAST InputRef lookups
        # 
        # Input: state[:access_plans] (from InputAccessPlannerPass)
        # Output: state[:input_table] (flat index with path arrays as keys)
        class InputIndexTablePass < PassBase
          def run(errors)
            access_plans = get_state(:access_plans)
            input_metadata = get_state(:input_metadata)
            
            raise "InputIndexTablePass requires access_plans" unless access_plans
            raise "InputIndexTablePass requires input_metadata" unless input_metadata

            input_table = {}
            
            # Transform access_plans into flat lookup table
            access_plans.each do |path_string, plan_list|
              plan = plan_list.first # All plans have same containers/dtype, different modes
              next unless plan

              path_array = path_string.split('.').map(&:to_sym).freeze
              dtype = extract_dtype_for_path(input_metadata, path_array, errors)
              next unless dtype

              input_table[path_array] = {
                axis: plan.containers.map(&:to_sym).freeze, # Reuse AccessPlanner's work!
                dtype: dtype
              }.freeze

              debug "  #{path_array.inspect} => axis: #{plan.containers.inspect}, dtype: #{dtype}"
            end

            debug "Generated #{input_table.size} entries"
            
            state.with(:input_table, input_table.freeze)
          end

          private

          def extract_dtype_for_path(input_metadata, path_array, errors)
            current = input_metadata
            
            path_array.each_with_index do |segment, idx|
              if idx == 0
                # Root level lookup
                current = current[segment]
                unless current
                  add_error(errors, nil, "Cannot find root segment '#{segment}' in input metadata")
                  return nil
                end
              else
                # Navigate to children
                unless current.respond_to?(:children) && current.children
                  add_error(errors, nil, "No children found at segment '#{path_array[0..idx-1].inspect}' when looking for '#{segment}'")
                  return nil
                end
                
                current = current.children[segment]
                unless current
                  add_error(errors, nil, "Cannot find segment '#{segment}' in path '#{path_array.inspect}' at index #{idx}")
                  return nil
                end
              end
            end

            unless current.respond_to?(:type)
              add_error(errors, nil, "No type found for path '#{path_array.inspect}'")
              return nil
            end

            current.type
          end
        end
      end
    end
  end
end