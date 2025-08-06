# frozen_string_literal: true

module Kumi
  module Core
    module Compiler
      # Function composition module for building registry function arguments
      # Takes broadcast metadata and delivers composed proc functions that extract arguments
      class RegistryArgumentBuilder
        
        # Main interface: given strategy metadata, returns a proc that builds arguments
        def self.build_argument_extractor(strategy)
          new.build_argument_extractor(strategy)
        end
        
        def initialize
          @extractors = build_extractors
        end
        
        def build_argument_extractor(strategy)
          extractor_specs = STRATEGY_SPECS[strategy] || raise("Unknown strategy: #{strategy}")
          
          # Return composed proc that builds arguments when called
          lambda do |expr, operands, ctx, bindings, accessors|
            args = []
            operand_index = 0
            
            extractor_specs.each do |spec_type|
              extractor = @extractors[spec_type]
              
              case spec_type
              when :operation_proc
                result = extractor.call(expr, operands, ctx, bindings, accessors, operand_index)
                args << result
              when :array_operand, :scalar_operand
                result = extractor.call(expr, operands, ctx, bindings, accessors, operand_index)
                args << result
                operand_index += 1
              when :parent_child_metadata
                result = extractor.call(expr, operands, ctx, bindings, accessors, operand_index)
                args.concat(result)  # This returns multiple values
              when :reduction_function, :reduction_input
                result = extractor.call(expr, operands, ctx, bindings, accessors, operand_index)
                args << result
              end
            end
            
            args
          end
        end
        
        private
        
        # Strategy specifications - define what each strategy needs
        STRATEGY_SPECS = {
          array_scalar_object: %i[operation_proc array_operand scalar_operand],
          element_wise_object: %i[operation_proc array_operand array_operand],
          parent_child_object: %i[operation_proc array_operand parent_child_metadata],
          array_scalar_vector: %i[operation_proc array_operand scalar_operand],
          element_wise_vector: %i[operation_proc array_operand array_operand],
          parent_child_vector: %i[operation_proc array_operand array_operand],
          simple_reduction: %i[reduction_function reduction_input]
        }.freeze
        
        # Composable extractors - each returns a proc that knows how to extract one type
        def build_extractors
          {
            operation_proc: lambda do |expr, _operands, _ctx, _bindings, _accessors, _index|
              Kumi::Registry.fetch(expr.fn_name)
            end,
            
            array_operand: lambda do |_expr, operands, ctx, bindings, accessors, index|
              extract_array_from_context(ctx, operands[index], bindings, accessors)
            end,
            
            scalar_operand: lambda do |_expr, operands, ctx, bindings, _accessors, index|
              extract_scalar_from_operand(operands[index], ctx, bindings)
            end,
            
            parent_child_metadata: lambda do |_expr, operands, ctx, bindings, accessors, _index|
              # Extract parent array (first operand)
              parent_array = extract_array_from_context(ctx, operands[0], bindings, accessors)
              
              # Extract field names from paths
              child_path = operands[0][:source][:path]
              parent_path = operands[1][:source][:path]
              
              child_field = child_path[-2].to_s
              child_value_field = child_path[-1].to_s  
              parent_value_field = parent_path[-1].to_s
              
              # Return all parent_child_object arguments
              [parent_array, child_field, child_value_field, parent_value_field]
            end,
            
            reduction_function: lambda do |expr, _operands, _ctx, _bindings, _accessors, _index|
              Kumi::Registry.fetch(expr.fn_name)
            end,
            
            reduction_input: lambda do |_expr, operands, ctx, bindings, accessors, _index|
              # Use pre-resolved operand resolver for pure lambda generation
              operand = operands[0]
              
              # Check if we already have a pre-resolved extractor for this operand
              if operand[:_resolved_extractor]
                # Use pre-resolved extractor - no runtime logic
                result = operand[:_resolved_extractor].call(ctx)
              else
                # Fallback to runtime resolution (should be avoided)
                result = extract_reduction_input(ctx, operand, bindings, accessors)
              end
              
              result
            end
          }
        end
        
        # Context extraction methods
        def extract_array_from_context(ctx, operand, bindings, accessors)
          source = operand[:source]
          
          case source[:kind]
          when :declaration
            binding = bindings[source[:name]]
            binding&.call(ctx)
          when :input_element
            path = source[:path]
            path_key = path.join('.')
            element_accessor_key = "#{path_key}:element"
            
            if accessors.key?(element_accessor_key)
              accessors[element_accessor_key].call(ctx)
            else
              raise "Missing accessor for #{path_key}:element - accessor system should have created this"
            end
          else
            raise "Unknown array source kind: #{source[:kind]}"
          end
        end
        
        def extract_scalar_from_operand(operand, ctx, bindings)
          source = operand[:source]
          
          case source[:kind]
          when :literal
            source[:value]
          when :input_field
            ctx[source[:name].to_s] || ctx[source[:name].to_sym]
          when :declaration
            binding = bindings[source[:name]]
            binding&.call(ctx)
          else
            raise "Unknown scalar source kind: #{source[:kind]}"
          end
        end
        
        def extract_reduction_input(ctx, operand, bindings, accessors)
          # First get the raw input data
          input_data = case operand[:source][:kind]
                       when :declaration
                         binding = bindings[operand[:source][:name]]
                         binding&.call(ctx)
                       when :input_element
                         extract_array_from_context(ctx, operand, bindings, accessors)
                       when :input_field
                         field_name = operand[:source][:name]
                         ctx[field_name.to_s] || ctx[field_name.to_sym]
                       when :nested_call
                         # For nested calls, we need to compile and execute them
                         # This is a more complex case that may need special handling
                         raise "Nested calls in reductions need special handling - should be pre-resolved"
                       else
                         raise "Unknown reduction input source: #{operand[:source][:kind]}"
                       end
          
          # Apply flattening if metadata indicates it's needed
          if operand[:requires_flattening]
            input_data.flatten
          else
            input_data
          end
        end
      end
    end
  end
end