# frozen_string_literal: true

module Kumi
  module Core
    module Compiler
      # Pre-compiles vectorized operations into pure lambda calls
      # Uses function composition to eliminate all runtime logic
      class VectorizedOperationCompiler
        
        def initialize(bindings, accessors)
          @operand_resolver = OperandResolver.new(bindings, accessors)
        end
        
        # Compile vectorized operation metadata into pure lambda
        # No runtime case statements, lookups, or logic
        def compile(expr, metadata)
          strategy = metadata[:strategy]
          operands = metadata[:operands] || []
          
          # Check strategy support first - fail fast during compilation
          unless supported_strategy?(strategy)
            raise "Unsupported strategy for pre-compilation: #{strategy}"
          end
          
          # Pre-resolve registry function - no runtime lookup
          registry_fn = Kumi::Registry.fetch(strategy)
          operation_proc = Kumi::Registry.fetch(expr.fn_name)
          
          # Pre-resolve all operand extractors - no runtime case statements
          operand_extractors = operands.map { |operand| @operand_resolver.resolve_operand(operand) }
          
          # Compose the pure lambda based on strategy
          compose_strategy_lambda(registry_fn, operation_proc, operand_extractors, strategy)
        end
        
        private
        
        def supported_strategy?(strategy)
          %i[array_scalar_object element_wise_object array_scalar_vector element_wise_vector].include?(strategy)
        end
        
        # Function composition for different strategies
        def compose_strategy_lambda(registry_fn, operation_proc, operand_extractors, strategy)
          case strategy
          when :array_scalar_object
            compose_array_scalar_object(registry_fn, operation_proc, operand_extractors)
          when :element_wise_object
            compose_element_wise_object(registry_fn, operation_proc, operand_extractors)
          when :array_scalar_vector
            compose_array_scalar_vector(registry_fn, operation_proc, operand_extractors)
          when :element_wise_vector
            compose_element_wise_vector(registry_fn, operation_proc, operand_extractors)
          else
            raise "Unsupported strategy for pre-compilation: #{strategy}"
          end
        end
        
        # Pure lambda composition - no runtime logic
        def compose_array_scalar_object(registry_fn, operation_proc, operand_extractors)
          array_extractor = operand_extractors[0]
          scalar_extractor = operand_extractors[1]
          
          # Pure lambda: registry_fn.call(operation_proc, array_values, scalar_value)
          lambda do |ctx|
            registry_fn.call(
              operation_proc,
              array_extractor.call(ctx),
              scalar_extractor.call(ctx)
            )
          end
        end
        
        def compose_element_wise_object(registry_fn, operation_proc, operand_extractors)
          array_extractor_1 = operand_extractors[0]
          array_extractor_2 = operand_extractors[1]
          
          # Pure lambda: registry_fn.call(operation_proc, array1, array2)
          lambda do |ctx|
            registry_fn.call(
              operation_proc,
              array_extractor_1.call(ctx),
              array_extractor_2.call(ctx)
            )
          end
        end
        
        def compose_array_scalar_vector(registry_fn, operation_proc, operand_extractors)
          array_extractor = operand_extractors[0]
          scalar_extractor = operand_extractors[1]
          
          # Pure lambda: registry_fn.call(operation_proc, array, scalar)
          lambda do |ctx|
            registry_fn.call(
              operation_proc,
              array_extractor.call(ctx),
              scalar_extractor.call(ctx)
            )
          end
        end
        
        def compose_element_wise_vector(registry_fn, operation_proc, operand_extractors)
          array_extractor_1 = operand_extractors[0]
          array_extractor_2 = operand_extractors[1]
          
          # Pure lambda: registry_fn.call(operation_proc, array1, array2)
          lambda do |ctx|
            registry_fn.call(
              operation_proc,
              array_extractor_1.call(ctx),
              array_extractor_2.call(ctx)
            )
          end
        end
      end
    end
  end
end