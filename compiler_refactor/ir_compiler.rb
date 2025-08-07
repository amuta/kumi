# frozen_string_literal: true

require_relative 'lambda_factory'
require_relative 'cascade_lambda_factory'

module Kumi
  module Core
    # Clean IR compiler using accessor-based approach
    # No more obsolete broadcasting strategies!
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
        when :element_wise
          @bindings[instruction[:name]] = compile_element_wise_operation(instruction)
        when :reduction
          @bindings[instruction[:name]] = compile_reduction_operation(instruction)
        when :array_reference
          @bindings[instruction[:name]] = compile_array_reference_operation(instruction)
        else
          raise "Unknown operation type: #{instruction[:operation_type]}"
        end
      end

      # Scalar operations - keep as is, they work fine
      def compile_scalar_operation(instruction)
        compilation = instruction[:compilation]
        
        case compilation[:type]
        when :call_expression
          compile_call_expression(compilation)
        when :cascade_expression
          compile_cascade_with_factory(compilation, instruction)  
        when :array_expression
          compile_array_expression(compilation)
        when :literal
          compile_literal(compilation)
        when :declaration_reference
          compile_declaration_reference(compilation)
        when :element_wise_operation
          # TAC-generated temp instructions can have element_wise_operation type in scalar context
          compile_element_wise_with_accessors(compilation)
        else
          raise "Unknown scalar compilation type: #{compilation[:type]}"
        end
      end

      # NEW: Clean vectorized operations using accessors + depth-aware mapping
      def compile_element_wise_operation(instruction)
        compilation = instruction[:compilation]
        
        case compilation[:type]
        when :element_wise_operation
          compile_element_wise_with_accessors(compilation)
        when :cascade_expression  # Element-wise cascades
          compile_cascade_with_factory(compilation, instruction)
        when :call_expression  # TAC-generated simple calls
          compile_call_expression(compilation)
        else
          raise "Unknown element_wise compilation type: #{compilation[:type]}"
        end
      end

      # Simple element-wise operations using pre-verified dimensions
      def compile_element_wise_with_accessors(compilation)
        factory = Core::LambdaFactory.new(@ir, @bindings)
        factory.build_element_wise_lambda(compilation)
      end

      # All cascades: use factory for clean decomposed approach
      def compile_cascade_with_factory(compilation, instruction = nil)
        factory = Core::CascadeLambdaFactory.new(@ir, @bindings, self)
        factory.build_cascade_lambda(compilation, instruction)
      end

      private


      # Simple array reference - just use the accessor
      def compile_array_reference_operation(instruction)
        compilation = instruction[:compilation]
        
        case compilation[:type]
        when :array_reference
          compile_operand(compilation[:operand])
        else
          raise "Unknown array reference compilation type: #{compilation[:type]}"
        end
      end

      # Reduction operations - keep simple
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
        operand_compiler = compile_operand(compilation[:operand])
        reduce_fn = Kumi::Registry.fetch(compilation[:function])
        
        lambda do |ctx|
          input_data = operand_compiler.call(ctx)
          # Flatten if needed for reductions
          flattened_data = input_data.is_a?(Array) && input_data.first.is_a?(Array) ? input_data.flatten : input_data
          reduce_fn.call(flattened_data)
        end
      end

      # ===== OPERAND COMPILATION (Keep clean) =====

      def compile_operand(operand)
        case operand[:type]
        when :input_reference
          compile_input_reference(operand)
        when :input_element_reference
          compile_input_element_reference(operand)
        when :literal
          compile_literal(operand)
        when :declaration_reference
          compile_declaration_reference(operand)
        when :call_expression
          compile_call_expression(operand)
        when :array_expression
          compile_array_expression(operand)
        else
          raise "Unknown operand type: #{operand[:type]}"
        end
      end

      def compile_input_reference(operand)
        accessor_key = operand[:accessor]
        accessor_lambda = @ir[:accessors][accessor_key]
        accessor_lambda || ->(ctx) { ctx[operand[:name]] }
      end

      def compile_input_element_reference(operand)
        accessor_key = operand[:accessor]  
        accessor_lambda = @ir[:accessors][accessor_key]
        accessor_lambda || ->(ctx) { nil }
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

      def compile_call_expression(operand)
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

      def compile_cascade_expression(operand)
        cases = operand[:cases]
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
    end
  end
end