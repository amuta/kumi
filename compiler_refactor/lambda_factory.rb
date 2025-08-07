# frozen_string_literal: true

module Kumi
  module Core
    # Factory for building specialized lambdas based on operand patterns
    class LambdaFactory
      def initialize(ir, bindings)
        @ir = ir
        @bindings = bindings
      end

      def build_element_wise_lambda(compilation)
        operation_fn = Kumi::Registry.fetch(compilation[:function])
        operation_reducer = Kumi::Registry.reducer?(compilation[:function])
        operand_pattern = analyze_operand_pattern(compilation[:operands])

        case operand_pattern
        when %i[array scalar]
          build_array_scalar_lambda(compilation, operation_fn)
        when %i[scalar array]
          build_scalar_array_lambda(compilation, operation_fn)
        when %i[array array]
          build_array_array_lambda(compilation, operation_fn)
        when %i[scalar scalar]
          build_scalar_scalar_lambda(compilation, operation_fn)
        when %i[array]
          return build_array_reducer_lambda(compilation, operation_fn) if operation_reducer

          raise "Unsupported element-wise operation with single array operand: #{compilation[:function]}" +
                " - operation needs to be a reduction for this pattern"
        else
          raise "Unsupported element-wise operand pattern: #{operand_pattern} for operation #{compilation[:function]}"
        end
      end

      private

      def analyze_operand_pattern(operands)
        operands.map do |operand|
          case operand[:type]
          when :input_element_reference
            :array  # Has accessor that returns array
          when :literal
            :scalar # Always scalar value
          when :input_reference
            :scalar # Simple field reference
          when :declaration_reference
            # Look up the operation type that produced this declaration
            analyze_declaration_pattern(operand[:name])
          when :call_expression
            # Nested call expression - this needs element-wise processing
            :array
          else
            raise "Unknown operand type for pattern analysis: #{operand[:type]}"
          end
        end
      end

      def analyze_declaration_pattern(declaration_name)
        # Find the instruction that creates this declaration
        instruction = @ir[:instructions].find { |instr| instr[:name] == declaration_name }
        return :scalar unless instruction

        case instruction[:operation_type]
        when :element_wise
          :array  # Element-wise operations produce arrays
        when :scalar, :reduction
          :scalar # Scalar and reduction operations produce single values
        else
          :scalar # Default to scalar for unknown types
        end
      end

      def build_array_reducer_lambda(compilation, operation_fn)
        # Special case for array reduction operations
        array_compiler = compile_operand(compilation[:operands][0])  # Array operand
        lambda do |ctx|
          array_values = array_compiler.call(ctx)
          array_values.map { |arr| operation_fn.call(arr) }
        end
      end

      def build_array_scalar_lambda(compilation, operation_fn)
        array_compiler = compile_operand(compilation[:operands][0])  # Array operand
        scalar_compiler = compile_operand(compilation[:operands][1]) # Scalar operand

        lambda do |ctx|
          array_values = array_compiler.call(ctx)
          scalar_value = scalar_compiler.call(ctx)
          array_values.map { |val| operation_fn.call(val, scalar_value) }
        end
      end

      def build_array_array_lambda(compilation, operation_fn)
        operand_compilers = compilation[:operands].map { |operand| compile_operand(operand) }

        lambda do |ctx|
          operand_values = operand_compilers.map { |compiler| compiler.call(ctx) }
          operand_values.first.zip(*operand_values[1..-1]).map { |vals| operation_fn.call(*vals) }
        end
      end

      def build_scalar_scalar_lambda(compilation, operation_fn)
        operand_compilers = compilation[:operands].map { |operand| compile_operand(operand) }

        lambda do |ctx|
          operand_values = operand_compilers.map { |compiler| compiler.call(ctx) }
          operation_fn.call(*operand_values)
        end
      end

      def compile_operand(operand)
        case operand[:type]
        when :input_reference
          accessor_key = operand[:accessor]
          accessor_lambda = @ir[:accessors][accessor_key]
          accessor_lambda || ->(ctx) { ctx[operand[:name]] }
        when :input_element_reference
          accessor_key = operand[:accessor]
          accessor_lambda = @ir[:accessors][accessor_key]
          accessor_lambda || ->(ctx) {}
        when :literal
          value = operand[:value]
          ->(_ctx) { value }
        when :declaration_reference
          name = operand[:name]
          lambda do |ctx|
            fn = @bindings[name]
            return nil unless fn

            fn.call(ctx)
          end
        when :call_expression
          # Nested call expression - recursively compile it
          fn = Kumi::Registry.fetch(operand[:function])
          operand_compilers = operand[:operands].map { |op| compile_operand(op) }

          lambda do |ctx|
            args = operand_compilers.map { |compiler| compiler.call(ctx) }
            fn.call(*args)
          end
        else
          raise "Unknown operand type: #{operand[:type]}"
        end
      end

      # Handle scalar op array pattern (reverse of array op scalar)
      def build_scalar_array_lambda(compilation, operation_fn)
        operand_compilers = compilation[:operands].map { |operand| compile_operand(operand) }

        lambda do |ctx|
          scalar_value = operand_compilers[0].call(ctx)  # First operand is scalar
          array_values = operand_compilers[1].call(ctx)  # Second operand is array

          # Broadcast scalar operation over array
          array_values.map { |array_elem| operation_fn.call(scalar_value, array_elem) }
        end
      end
    end
  end
end
