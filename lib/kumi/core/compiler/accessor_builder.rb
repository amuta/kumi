# frozen_string_literal: true

module Kumi
  module Core
    module Compiler
      # Takes access plans from AccessorPlanner and generates pure lambda functions.
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

          @accessors.freeze
        end

        private

        # All plan types are built using the same composition logic.
        def build_accessor_from_plan(plan)
          compose_operations(plan[:operations])
        end

        def compose_operations(operations)
          # Build from right to left (inside out) to create a left-to-right execution chain.
          operations.reverse.reduce(identity_lambda) do |composed_lambda, operation|
            build_operation_lambda(operation, composed_lambda)
          end
        end

        def build_operation_lambda(operation, next_op)
          case operation[:type]
          when :enter_object
            key = operation[:key]
            lambda do |data|
              # Only attempt to access a key if the data is a Hash.
              if data.is_a?(Hash)
                value = data[key.to_s] || data[key.to_sym]
                next_op.call(value)
              else
                # If data is not a hash, the path is broken. Propagate nil.
                next_op.call(nil)
              end
            end

          when :enter_array
            lambda do |data|
              # Only attempt to map if the data is an Array.
              if data.is_a?(Array)
                data.map { |item| next_op.call(item) }
              else
                # If we expect an array but don't have one, the path is broken.
                # The result of a map on a non-array should be nil.
                nil
              end
            end

          when :flatten
            # dont think this is the correct way
            # Flatten should be explicit - for comparing and reducing ... i feel this is not the way
            # lambda do |data|
            #   result = next_op.call(data)
            #   result.is_a?(Array) ? result.flatten : result
            # end
          end
        end

        def identity_lambda
          ->(data) { data }
        end
      end
    end
  end
end
