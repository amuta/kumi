# frozen_string_literal: true

module Kumi
  module Core
    module IRGeneratorModules
      # Handles compilation info generation for different operation types
      module ExpressionIR
        private

        def generate_compilation_info(expression, operation_type, metadata)
          case operation_type
          when :scalar
            generate_scalar_compilation(expression)
          when :element_wise
            generate_element_wise_compilation(expression, metadata)
          when :reduction
            generate_reduction_compilation(expression, metadata)
          when :array_reference
            generate_array_reference_compilation(expression, metadata)
          else
            raise "Unknown operation type: #{operation_type}"
          end
        end

        def generate_scalar_compilation(expression)
          case expression
          when Kumi::Syntax::CallExpression
            {
              type: :call_expression,
              function: expression.fn_name,
              operands: expression.args.map { |arg| generate_operand_info(arg) }
            }
          when Kumi::Syntax::CascadeExpression
            @cascade_ir_generator.generate_cascade_compilation(expression)
          when Kumi::Syntax::ArrayExpression
            {
              type: :array_expression,
              elements: expression.elements.map { |elem| generate_operand_info(elem) }
            }
          when Kumi::Syntax::Literal
            {
              type: :literal,
              value: expression.value
            }
          when Kumi::Syntax::DeclarationReference
            {
              type: :declaration_reference,
              name: expression.name
            }
          else
            raise "Unsupported scalar expression type: #{expression.class}"
          end
        end

        def generate_element_wise_compilation(expression, metadata)
          case expression
          when Kumi::Syntax::CallExpression
            generate_element_wise_call_compilation(expression, metadata)
          when Kumi::Syntax::CascadeExpression
            # All cascades use same IR structure - factory handles element-wise logic
            @cascade_ir_generator.generate_cascade_compilation(expression)
          else
            raise "Unsupported element-wise expression type: #{expression.class}"
          end
        end
        
        def generate_element_wise_call_compilation(expression, metadata)
          strategy = metadata[:strategy]
          registry_function = metadata.dig(:registry_call_info, :function_name)
          
          {
            type: :element_wise_operation,
            strategy: strategy,
            function: expression.fn_name,  # Original operation (multiply, add, etc.)
            registry_function: registry_function,  # Broadcasting function (element_wise_object, etc.)
            operands: generate_element_wise_operands(metadata[:operands] || [])
          }
        end

        def generate_array_reference_compilation(expression, metadata)
          # Direct array field access - just return the operand info
          {
            type: :array_reference,
            operand: generate_operand_info(expression)
          }
        end

        def generate_reduction_compilation(expression, metadata)
          # Reduction operations like fn(:sum, array_operand)
          {
            type: :reduction_operation,
            function: metadata[:function] || expression.fn_name,
            requires_flattening: metadata[:requires_flattening] || false,
            operand: generate_operand_info(expression.args.first)
          }
        end
      end
    end
  end
end