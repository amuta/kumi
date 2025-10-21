# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        # RESPONSIBILITY: Propagate constraints forward and backward through operations
        # DEPENDENCIES: :registry (function registry), constraint metadata from function specs
        # INTERFACE: propagate_forward(constraint), propagate_reverse_through_operation(...)
        #
        # Implements formal constraint propagation rules based on function semantics.
        # Forward: x == 5, y = x + 10 => y == 15
        # Reverse: y == 15, y = x + 10 => x == 5
        class FormalConstraintPropagator
          def initialize(schema, state)
            @schema = schema
            @state = state
            @registry = state[:registry]
          end

          # Forward propagate a constraint through a single operation
          def propagate_forward_through_operation(constraint, operation_spec, operand_map)
            case constraint[:op]
            when :==
              propagate_equality_forward(constraint, operation_spec, operand_map)
            when :range
              propagate_range_forward(constraint, operation_spec, operand_map)
            end
          end

          # Reverse propagate: derive input constraints from output constraints
          def propagate_reverse_through_operation(constraint, operation_spec, operand_map)
            case constraint[:op]
            when :==
              propagate_equality_reverse(constraint, operation_spec, operand_map)
            when :range
              propagate_range_reverse(constraint, operation_spec, operand_map)
            end
          end

          private

          # FORWARD PROPAGATION: Compute output value from input constraints
          def propagate_equality_forward(constraint, operation_spec, operand_map)
            result_var = operand_map[:result]
            constraint[:variable]
            input_value = constraint[:value]

            case operation_spec.id
            when "core.add"
              # x == V, result = x + C => result == V + C
              other_operand = get_other_operand_value(constraint, operand_map, "add")
              return nil unless other_operand.is_a?(Numeric)

              output_value = input_value + other_operand
              { variable: result_var, op: :==, value: output_value }

            when "core.mul"
              # x == V, result = x * C => result == V * C
              other_operand = get_other_operand_value(constraint, operand_map, "mul")
              return nil unless other_operand.is_a?(Numeric)

              output_value = input_value * other_operand
              { variable: result_var, op: :==, value: output_value }

            when "core.sub"
              # x == V, result = x - C => result == V - C
              other_operand = get_other_operand_value(constraint, operand_map, "sub")
              return nil unless other_operand.is_a?(Numeric)

              output_value = input_value - other_operand
              { variable: result_var, op: :==, value: output_value }

            end
          end

          # FORWARD PROPAGATION: Compute output range from input range
          def propagate_range_forward(constraint, operation_spec, operand_map)
            result_var = operand_map[:result]
            input_min = constraint[:min]
            input_max = constraint[:max]

            case operation_spec.id
            when "core.add"
              # x in [min, max], result = x + C => result in [min + C, max + C]
              other = get_other_operand_value(constraint, operand_map, "add")
              return nil unless other.is_a?(Numeric)

              output_min = input_min + other
              output_max = input_max + other
              { variable: result_var, op: :range, min: output_min, max: output_max }

            when "core.mul"
              # x in [min, max], result = x * C => depends on sign of C
              other = get_other_operand_value(constraint, operand_map, "mul")
              return nil unless other.is_a?(Numeric)

              if other > 0
                output_min = input_min * other
                output_max = input_max * other
              elsif other < 0
                output_min = input_max * other
                output_max = input_min * other
              else
                output_min = 0
                output_max = 0
              end
              { variable: result_var, op: :range, min: output_min, max: output_max }

            when "core.sub"
              # x in [min, max], result = x - C => result in [min - C, max - C]
              other = get_other_operand_value(constraint, operand_map, "sub")
              return nil unless other.is_a?(Numeric)

              output_min = input_min - other
              output_max = input_max - other
              { variable: result_var, op: :range, min: output_min, max: output_max }

            end
          end

          # REVERSE PROPAGATION: Derive input equality from output equality
          def propagate_equality_reverse(constraint, operation_spec, operand_map)
            constraint[:variable]
            result_value = constraint[:value]
            left_var = operand_map[:left_operand]
            right_var = operand_map[:right_operand]

            case operation_spec.id
            when "core.add"
              # result == V, result = x + C => x == V - C
              if left_var.is_a?(Symbol) && right_var.is_a?(Numeric)
                { variable: left_var, op: :==, value: result_value - right_var }
              elsif right_var.is_a?(Symbol) && left_var.is_a?(Numeric)
                { variable: right_var, op: :==, value: result_value - left_var }
              end

            when "core.mul"
              # result == V, result = x * C => x == V / C (if C != 0)
              if left_var.is_a?(Symbol) && right_var.is_a?(Numeric) && right_var != 0
                return nil unless (result_value % right_var).zero?

                { variable: left_var, op: :==, value: result_value / right_var }
              elsif right_var.is_a?(Symbol) && left_var.is_a?(Numeric) && left_var != 0
                return nil unless (result_value % left_var).zero?

                { variable: right_var, op: :==, value: result_value / left_var }
              end

            when "core.sub"
              # result == V, result = x - C => x == V + C
              if left_var.is_a?(Symbol) && right_var.is_a?(Numeric)
                { variable: left_var, op: :==, value: result_value + right_var }
              elsif right_var.is_a?(Symbol) && left_var.is_a?(Numeric)
                { variable: right_var, op: :==, value: left_var - result_value }
              end

            end
          end

          # REVERSE PROPAGATION: Derive input range from output range
          def propagate_range_reverse(constraint, operation_spec, operand_map)
            result_min = constraint[:min]
            result_max = constraint[:max]
            left_var = operand_map[:left_operand]
            right_var = operand_map[:right_operand]

            case operation_spec.id
            when "core.add"
              # result in [min, max], result = x + C => x in [min - C, max - C]
              if left_var.is_a?(Symbol) && right_var.is_a?(Numeric)
                return { variable: left_var, op: :range, min: result_min - right_var, max: result_max - right_var }
              elsif right_var.is_a?(Symbol) && left_var.is_a?(Numeric)
                return { variable: right_var, op: :range, min: result_min - left_var, max: result_max - left_var }
              end

            when "core.mul"
              # result in [min, max], result = x * C => x in [min/C, max/C] (depends on sign)
              if left_var.is_a?(Symbol) && right_var.is_a?(Numeric) && right_var != 0
                return { variable: left_var, op: :range, min: result_min / right_var, max: result_max / right_var } if right_var > 0

                return { variable: left_var, op: :range, min: result_max / right_var, max: result_min / right_var }

              elsif right_var.is_a?(Symbol) && left_var.is_a?(Numeric) && left_var != 0
                return { variable: right_var, op: :range, min: result_min / left_var, max: result_max / left_var } if left_var > 0

                return { variable: right_var, op: :range, min: result_max / left_var, max: result_min / left_var }

              end

            when "core.sub"
              # result in [min, max], result = x - C => x in [min + C, max + C]
              if left_var.is_a?(Symbol) && right_var.is_a?(Numeric)
                return { variable: left_var, op: :range, min: result_min + right_var, max: result_max + right_var }
              elsif right_var.is_a?(Symbol) && left_var.is_a?(Numeric)
                return { variable: right_var, op: :range, min: left_var - result_max, max: left_var - result_min }
              end
            end

            nil
          end

          def get_other_operand_value(constraint, operand_map, _operation)
            input_var = constraint[:variable]
            left_var = operand_map[:left_operand] || operand_map.values[0]
            right_var = operand_map[:right_operand] || operand_map.values[1]

            if input_var == left_var && right_var.is_a?(Numeric)
              right_var
            elsif input_var == right_var && left_var.is_a?(Numeric)
              left_var
            end
          end
        end
      end
    end
  end
end
