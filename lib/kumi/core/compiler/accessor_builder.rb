# frozen_string_literal: true

module Kumi
  module Core
    module Compiler
      # Takes access plans from AccessorPlanner and generates actual lambda functions
      # Uses metaprogramming to build optimized accessors based on the plans
      class AccessorBuilder
        def self.build(access_plans)
          new(access_plans).build
        end

        def initialize(access_plans)
          @access_plans = access_plans
          @accessors = {}
        end

        def build
          @access_plans.each do |path_key, plans|
            plans.each do |accessor_type, plan|
              accessor_key = "#{path_key}:#{accessor_type}"
              @accessors[accessor_key] = build_accessor_from_plan(plan)
            end
          end
          
          @accessors.freeze # Returns the frozen hash
        end

        private

        def build_accessor_from_plan(plan)
          case plan[:type]
          when :structure
            build_structure_accessor(plan)
          when :element
            build_element_accessor(plan)
          when :flattened
            build_flattened_accessor(plan)
          else
            raise "Unknown accessor plan type: #{plan[:type]}"
          end
        end

        def build_structure_accessor(plan)
          operations = plan[:operations]
          build_smart_accessor(operations)
        end

        def build_element_accessor(plan)
          operations = plan[:operations]
          build_smart_accessor(operations)
        end

        def build_flattened_accessor(plan)
          operations = plan[:operations]
          build_smart_accessor(operations)
        end
        
        def build_smart_accessor(operations)
          compose_operations(operations)
        end

        def compose_operations(operations)
          # Special handling for flatten - it should be applied at the end
          has_flatten = operations.any? { |op| op[:type] == :flatten }
          ops_without_flatten = operations.reject { |op| op[:type] == :flatten }
          
          # Build from right to left (inside out)
          base_lambda = ops_without_flatten.reverse.reduce(identity_lambda) do |next_op, operation|
            build_operation_lambda(operation, next_op)
          end
          
          # Apply flatten at the end if needed
          if has_flatten
            lambda { |data| base_lambda.call(data).flatten }
          else
            base_lambda
          end
        end

        def build_operation_lambda(operation, next_op)
          case operation[:type]
          when :fetch
            key = operation[:key]
            # Support both string and symbol keys for compatibility
            lambda { |data| 
              if data.is_a?(Hash)
                # Try string first, then symbol as fallback
                value = data[key.to_s] || data[key.to_sym]
                next_op.call(value)
              elsif data.is_a?(Array) && key.is_a?(Integer)
                next_op.call(data[key])
              else
                next_op.call(data)
              end
            }
            
          when :enter_array
            lambda { |data| 
              if data.is_a?(Array)
                data.map { |item| next_op.call(item) }
              else
                next_op.call(data)
              end
            }
            
          when :flatten
            # Flatten happens AFTER getting the data
            lambda { |data| 
              result = next_op.call(data)
              result.is_a?(Array) ? result.flatten : result
            }
          end
        end

        def identity_lambda
          lambda { |data| data }
        end

      end
    end
  end
end