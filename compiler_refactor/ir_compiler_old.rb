# frozen_string_literal: true

module Kumi
  module Core
    # New compiler that works with structured IR instead of digging through analyzer state
    class IRCompiler
      def initialize(ir)
        @ir = ir
        @bindings = {}
      end

      def compile
        # Compile in the order specified by IR instructions
        @ir[:instructions].each do |instruction|
          compile_instruction(instruction)
        end

        Core::CompiledSchema.new(@bindings.freeze)
      end

      private

      def compile_instruction(instruction)
        case instruction[:operation_type]
        when :scalar
          @bindings[instruction[:name]] = compile_scalar_operation(instruction)
        when :vectorized
          @bindings[instruction[:name]] = compile_vectorized_operation(instruction)
        when :reduction
          @bindings[instruction[:name]] = compile_reduction_operation(instruction)
        when :array_reference
          @bindings[instruction[:name]] = compile_array_reference_operation(instruction)
        else
          raise "Unknown operation type: #{instruction[:operation_type]}"
        end
      end

      def compile_scalar_operation(instruction)
        compilation = instruction[:compilation]
        
        case compilation[:type]
        when :call_expression
          compile_scalar_call(compilation)
        when :cascade_expression
          compile_scalar_cascade(compilation)
        when :array_expression
          compile_array_expression(compilation)
        when :literal
          compile_literal(compilation)
        when :declaration_reference
          compile_declaration_reference(compilation)
        else
          raise "Unknown scalar compilation type: #{compilation[:type]}"
        end
      end

      def compile_scalar_call(compilation)
        fn = Kumi::Registry.fetch(compilation[:function])
        operand_compilers = compilation[:operands].map { |operand| compile_operand(operand) }

        lambda do |ctx|
          args = operand_compilers.map { |compiler| compiler.call(ctx) }
          fn.call(*args)
        end
      end

      def compile_scalar_cascade(compilation)
        cases = compilation[:cases]
        conditional_cases = cases.select { |c| c[:condition] }
        base_case = cases.find { |c| c[:condition].nil? }

        condition_compilers = conditional_cases.map { |c| compile_operand(c[:condition]) }
        result_compilers = conditional_cases.map { |c| compile_operand(c[:result]) }
        base_compiler = base_case ? compile_operand(base_case[:result]) : nil

        lambda do |ctx|
          condition_compilers.each_with_index do |cond_compiler, i|
            return result_compilers[i].call(ctx) if cond_compiler.call(ctx)
          end
          base_compiler&.call(ctx)
        end
      end

      def compile_operand(operand)
        case operand[:type]
        when :input_reference
          compile_input_reference(operand)
        when :literal
          compile_literal(operand)
        when :input_element_reference
          compile_input_element_reference(operand)
        when :declaration_reference
          compile_declaration_reference(operand)
        when :call_expression
          compile_operand_call(operand)
        when :array_expression
          compile_array_expression(operand)
        else
          raise "Unknown operand type: #{operand[:type]}"
        end
      end

      def compile_input_reference(operand)
        # Use pre-built accessor from IR
        accessor_key = operand[:accessor]
        accessor_lambda = @ir[:accessors][accessor_key]
        
        # Return the pre-built accessor lambda directly
        accessor_lambda || ->(ctx) { ctx[operand[:name]] }  # fallback to simple access
      end

      def compile_input_element_reference(operand)
        # Use pre-built accessor from IR for element access
        accessor_key = operand[:accessor]
        accessor_lambda = @ir[:accessors][accessor_key]
        
        # Return the pre-built accessor lambda
        accessor_lambda || ->(ctx) { nil }  # fallback
      end

      def compile_literal(operand)
        value = operand[:value]
        ->(_ctx) { value }
      end

      def compile_declaration_reference(operand)
        name = operand[:name]
        lambda do |ctx|
          fn = @bindings[name]
          return nil unless fn
          fn.call(ctx)
        end
      end

      def compile_operand_call(operand)
        fn = Kumi::Registry.fetch(operand[:function])
        operand_compilers = operand[:operands].map { |op| compile_operand(op) }

        lambda do |ctx|
          args = operand_compilers.map { |compiler| compiler.call(ctx) }
          fn.call(*args)
        end
      end

      def compile_array_expression(operand)
        element_compilers = operand[:elements].map { |elem| compile_operand(elem) }
        
        lambda do |ctx|
          element_compilers.map { |compiler| compiler.call(ctx) }
        end
      end

      def compile_vectorized_operation(instruction)
        compilation = instruction[:compilation]
        
        case compilation[:type]
        when :vectorized_operation
          compile_vectorized_call(compilation)
        else
          raise "Unknown vectorized compilation type: #{compilation[:type]}"
        end
      end

      def compile_vectorized_call(compilation)
        strategy = compilation[:strategy]
        operation_fn = Kumi::Registry.fetch(compilation[:function])
        registry_fn = Kumi::Registry.fetch(compilation[:registry_function])
        
        # Compile operands to extractors
        operand_compilers = compilation[:operands].map { |operand| compile_operand(operand) }
        
        # Build strategy-specific lambda based on existing VectorizedOperationCompiler patterns
        case strategy
        when :array_function_object, :array_function_vector
          # Single array operand with function: registry_fn.call(operation_fn, array)
          array_compiler = operand_compilers.first
          ->(ctx) { registry_fn.call(operation_fn, array_compiler.call(ctx)) }
        when :element_wise_object, :element_wise_vector
          # Two array operands: registry_fn.call(operation_fn, array1, array2)
          array1_compiler, array2_compiler = operand_compilers
          ->(ctx) { registry_fn.call(operation_fn, array1_compiler.call(ctx), array2_compiler.call(ctx)) }
        when :array_scalar_object, :array_scalar_vector
          # Array and scalar: registry_fn.call(operation_fn, array, scalar)
          array_compiler, scalar_compiler = operand_compilers
          ->(ctx) { registry_fn.call(operation_fn, array_compiler.call(ctx), scalar_compiler.call(ctx)) }
        else
          raise "Unsupported vectorized strategy: #{strategy}"
        end
      end

      def compile_array_reference_operation(instruction)
        compilation = instruction[:compilation]
        
        case compilation[:type]
        when :array_reference
          # Simple operand compilation - just extract the array field
          compile_operand(compilation[:operand])
        else
          raise "Unknown array reference compilation type: #{compilation[:type]}"
        end
      end

      def compile_reduction_operation(instruction)
        compilation = instruction[:compilation]
        
        case compilation[:type]
        when :reduction_operation
          compile_reduction_call(compilation)
        else
          raise "Unknown reduction compilation type: #{compilation[:type]}"
        end
      end

      def compile_reduction_call(compilation)
        # Compile the operand extractor
        operand_compiler = compile_operand(compilation[:operand])
        
        # Apply flattening if needed
        final_extractor = if compilation[:requires_flattening]
                           ->(ctx) { operand_compiler.call(ctx)&.flatten }
                         else
                           operand_compiler
                         end
        
        # Get the reduction function
        reduce_fn = Kumi::Registry.fetch(compilation[:function])
        
        lambda do |ctx|
          input_data = final_extractor.call(ctx)
          reduce_fn.call(input_data)
        end
      end
    end
  end
end