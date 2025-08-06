# frozen_string_literal: true

module Kumi
  module Core
    module Compiler
      # RESPONSIBILITY: Compiles vectorized operations (e.g., array + scalar)
      # by composing pure lambdas at compile-time. It uses the ExpressionBuilder
      # as the single source of truth for compiling operand expressions.
      class VectorizedOperationCompiler
        def initialize(expression_builder)
          @expression_builder = expression_builder
        end

        def compile(expr, metadata)
          strategy = metadata[:strategy]
          # The metadata from the BroadcastDetector must now contain the original AST nodes for the operands.
          operand_asts = metadata[:operands] || []

          # 1. Use the unified ExpressionBuilder to compile each operand's AST node into a data-extraction lambda.
          resolved_extractors = operand_asts.map do |operand_ast|
            @expression_builder.compile(operand_ast)
          end

          # 2. Pre-resolve the functions from the registry at compile-time.
          operation_fn = Kumi::Registry.fetch(expr.fn_name)
          registry_fn = Kumi::Registry.fetch(strategy)

          # 3. Compose the final, pure lambda based on the strategy.
          build_strategy_lambda(strategy, operation_fn, registry_fn, resolved_extractors, metadata)
        end

        private

        # This method contains the compositional logic that was previously in the main RubyCompiler.
        # It takes the pre-resolved functions and operand extractors and composes them into a final lambda.
        def build_strategy_lambda(strategy, operation_fn, registry_fn, extractors, metadata)
          case strategy
          when :array_scalar_object, :array_scalar_vector
            array_ex, scalar_ex = extractors
            ->(ctx) { registry_fn.call(operation_fn, array_ex.call(ctx), scalar_ex.call(ctx)) }

          when :element_wise_object, :element_wise_vector
            array1_ex, array2_ex = extractors
            ->(ctx) { registry_fn.call(operation_fn, array1_ex.call(ctx), array2_ex.call(ctx)) }

          when :parent_child_vector
            nested_ex, parent_ex = extractors
            ->(ctx) { registry_fn.call(operation_fn, nested_ex.call(ctx), parent_ex.call(ctx)) }

          when :parent_child_object
            # For this complex strategy, we also need to extract path metadata.
            # This assumes the BroadcastDetector provides this info.
            parent_ex = extractors[0]
            child_path = metadata.dig(:operands, 0, :source, :path)
            parent_path = metadata.dig(:operands, 1, :source, :path)

            # Extract field names from the AST paths.
            child_field = child_path[-2].to_s
            child_value_field = child_path[-1].to_s
            parent_value_field = parent_path[-1].to_s

            lambda do |ctx|
              parent_array = parent_ex.call(ctx)
              registry_fn.call(operation_fn, parent_array, child_field, child_value_field, parent_value_field)
            end

          else
            raise "VectorizedOperationCompiler: Unknown or unsupported strategy: #{strategy}"
          end
        end
      end
    end
  end
end
