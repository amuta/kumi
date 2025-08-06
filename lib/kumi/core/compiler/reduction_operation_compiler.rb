# frozen_string_literal: true

module Kumi
  module Core
    module Compiler
      # RESPONSIBILITY: Compiles reduction operations (e.g., fn(:size, ...)).
      class ReductionOperationCompiler
        def initialize(expression_builder)
          @expression_builder = expression_builder
        end

        def compile(expr, metadata)
          # The operand is the first argument's AST node.
          # Note: The broadcast detector's metadata must contain the AST node.
          operand_ast = expr.args.first

          # Use the unified ExpressionBuilder to compile the operand.
          resolved_extractor = @expression_builder.compile(operand_ast)

          # Wrap the extractor in a flatten call if needed.
          final_extractor = if metadata[:requires_flattening]
                              ->(ctx) { resolved_extractor.call(ctx)&.flatten }
                            else
                              resolved_extractor
                            end

          reduce_fn = Kumi::Registry.fetch(metadata[:function])

          lambda do |ctx|
            input_data = final_extractor.call(ctx)
            reduce_fn.call(input_data)
          end
        end
      end
    end
  end
end
