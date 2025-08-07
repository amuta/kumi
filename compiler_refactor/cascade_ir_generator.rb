# frozen_string_literal: true

module Kumi
  module Core
    # Handles cascade-specific IR generation
    class CascadeIrGenerator
      def initialize(ir_generator)
        @ir_generator = ir_generator
      end

      def generate_cascade_compilation(expression, broadcast_metadata = nil)
        compilation = {
          type: :cascade_expression,
          cases: expression.cases.map { |cascade_case| generate_cascade_case_info(cascade_case) }
        }
        
        # Add broadcast metadata if available
        if broadcast_metadata
          compilation[:broadcast_metadata] = broadcast_metadata
          compilation[:dimension_info] = {
            depth: broadcast_metadata[:case_analyses]&.first&.dig(:metadata, :depth),
            dimension_mode: broadcast_metadata[:case_analyses]&.first&.dig(:metadata, :dimension_mode),
            access_mode: broadcast_metadata[:case_analyses]&.first&.dig(:metadata, :access_mode)
          }
          compilation[:case_analyses] = broadcast_metadata[:case_analyses]
        end
        
        compilation
      end

      private

      def generate_cascade_case_info(cascade_case)
        condition_info = if cascade_case.condition
          # Check if this is a cascade_and call - if so, extract trait references directly
          if cascade_case.condition.is_a?(Kumi::Syntax::CallExpression) && 
             cascade_case.condition.fn_name == :cascade_and
            # Extract the trait references directly
            trait_refs = cascade_case.condition.args.map do |arg|
              @ir_generator.generate_operand_info(arg)
            end
            {
              type: :trait_evaluation,
              traits: trait_refs
            }
          else
            @ir_generator.generate_operand_info(cascade_case.condition)
          end
        else
          nil
        end

        {
          condition: condition_info,
          result: generate_cascade_result_info(cascade_case.result)
        }
      end

      def generate_cascade_result_info(result_expr)
        # Check if this result expression needs TAC decomposition
        if needs_tac_decomposition_for_expression?(result_expr)
          # Recursively decompose nested expressions into temps
          decompose_cascade_result_expression(result_expr)
        else
          # Simple expression - generate normally
          @ir_generator.generate_operand_info(result_expr)
        end
      end

      def needs_tac_decomposition_for_expression?(expr)
        case expr
        when Kumi::Syntax::CallExpression
          # Check if any arguments are also call expressions (nested calls)
          expr.args.any? { |arg| arg.is_a?(Kumi::Syntax::CallExpression) }
        else
          false
        end
      end

      def decompose_cascade_result_expression(expr)
        # Recursively decompose this expression
        case expr
        when Kumi::Syntax::CallExpression
          # First, decompose all nested argument expressions
          decomposed_operands = expr.args.map do |arg|
            if arg.is_a?(Kumi::Syntax::CallExpression)
              # This argument is a nested call - decompose it to a temp
              temp_result = decompose_cascade_result_expression(arg)
              # Convert temp result back to declaration reference
              {
                type: :declaration_reference,
                name: temp_result[:name]
              }
            else
              # Simple argument - generate normally
              @ir_generator.generate_operand_info(arg)
            end
          end
          
          # Create temp for this level of the expression
          temp_name = @ir_generator.generate_temp_name
          temp_instruction = create_temp_for_cascade_expression(temp_name, expr.fn_name, decomposed_operands)
          @ir_generator.add_pending_temp_instruction(temp_instruction)
          
          # Return reference to the temp
          {
            name: temp_name,
            type: :declaration_reference
          }
        else
          # Not a call expression - just generate normally
          @ir_generator.generate_operand_info(expr)
        end
      end

      def create_temp_for_cascade_expression(temp_name, function, operands)
        {
          name: temp_name,
          type: :valuedeclaration,
          operation_type: :element_wise,  # Assume element-wise for cascade context
          data_type: { array: :float },   # TODO: Better type inference
          compilation: {
            type: :element_wise_operation,
            strategy: nil,
            function: function,
            registry_function: nil,
            operands: operands
          },
          temp: true
        }
      end

    end
  end
end