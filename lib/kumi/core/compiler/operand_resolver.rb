# frozen_string_literal: true

module Kumi
  module Core
    module Compiler
      # Pre-compiles operand extraction into pure lambda calls
      # No runtime logic - everything resolved during compilation
      class OperandResolver
        
        def initialize(bindings, accessors)
          @bindings = bindings
          @accessors = accessors
        end
        
        # Pre-compile an operand into a pure extraction lambda
        # Returns a lambda that when called with ctx, returns the operand value
        def resolve_operand(operand)
          source = operand[:source]
          
          case source[:kind]
          when :declaration
            resolve_declaration_operand(source)
          when :input_element  
            resolve_input_element_operand(source)
          when :input_field
            resolve_input_field_operand(source)
          when :literal
            resolve_literal_operand(source)
          when :nested_call
            resolve_nested_call_operand(source, operand)
          else
            raise "Unknown operand source kind: #{source[:kind]}"
          end
        end
        
        private
        
        # Pre-resolve declaration reference - no runtime binding lookup
        def resolve_declaration_operand(source)
          resolved_binding = @bindings[source[:name]]
          raise "Missing binding for declaration: #{source[:name]}" unless resolved_binding
          
          # Return pure lambda - just calls pre-resolved binding
          lambda { |ctx| resolved_binding.call(ctx) }
        end
        
        # Pre-resolve input element access - no runtime accessor lookup
        def resolve_input_element_operand(source)
          path_key = source[:path].join('.')
          element_accessor_key = "#{path_key}:element"
          resolved_accessor = @accessors[element_accessor_key]
          raise "Missing accessor for: #{element_accessor_key}" unless resolved_accessor
          
          # Return pure lambda - just calls pre-resolved accessor
          lambda { |ctx| resolved_accessor.call(ctx) }
        end
        
        # Pre-resolve input field access - pure field extraction
        def resolve_input_field_operand(source)
          field_name_str = source[:name].to_s
          field_name_sym = source[:name].to_sym
          
          # Return pure lambda - just extracts field (with symbol fallback)
          lambda do |ctx|
            ctx[field_name_str] || ctx[field_name_sym]
          end
        end
        
        # Pre-resolve literal - pure value return
        def resolve_literal_operand(source)
          resolved_value = source[:value]
          
          # Return pure lambda - just returns pre-resolved value
          lambda { |_ctx| resolved_value }
        end
        
        # Nested calls should use fallback path - accessor system handles them
        def resolve_nested_call_operand(_source, _operand)
          # OperandResolver doesn't handle nested calls - they should use fallback extraction
          # which delegates to the accessor system that already handles complex patterns
          raise "Nested calls should use fallback path, not OperandResolver"
        end
      end
    end
  end
end