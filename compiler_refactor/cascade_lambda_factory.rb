# frozen_string_literal: true

module Kumi
  module Core
    # Factory for building element-wise cascade lambdas using decomposed approach
    class CascadeLambdaFactory
      def initialize(ir, bindings, ir_compiler)
        @ir = ir
        @bindings = bindings
        @ir_compiler = ir_compiler
      end

      def build_cascade_lambda(compilation, instruction = nil)
        cases = compilation[:cases]
        
        # Build condition/value binding pairs
        cascade_pairs = cases.map.with_index do |cascade_case, idx|
          condition_binding = if cascade_case[:condition]
            # Use existing binding or compile the condition
            compile_cascade_component(cascade_case[:condition], "condition_#{idx}")
          else
            # Base case - always true
            ->(_ctx) { true }
          end
          
          value_binding = compile_cascade_component(cascade_case[:result], "value_#{idx}")
          
          { condition: condition_binding, value: value_binding }
        end
        
        # Use instruction's operation_type to determine element-wise vs scalar
        is_element_wise = instruction && instruction[:operation_type] == :element_wise
        
        if is_element_wise
          # Element-wise cascade: map over each element
          build_element_wise_cascade_iterator(cascade_pairs)
        else
          # Scalar cascade: simple conditional logic
          build_scalar_cascade_iterator(cascade_pairs)
        end
      end

      private

      def compile_cascade_component(component, debug_name)
        case component[:type]
        when :trait_evaluation
          # Direct trait evaluation - just get the bindings and evaluate them
          compile_trait_evaluation(component)
        when :call_expression
          if should_be_element_wise?(component)
            # Delegate to LambdaFactory for element-wise operations
            compile_element_wise_call_expression(component)
          else
            # Regular scalar call expression
            @ir_compiler.send(:compile_call_expression, component)
          end
        else
          # Simple operands can use the operand compiler
          @ir_compiler.send(:compile_operand, component)
        end
      end
      
      def should_be_element_wise?(call_expr)
        # Check if any operand references an element-wise declaration
        call_expr[:operands].any? do |operand|
          if operand[:type] == :declaration_reference
            decl_name = operand[:name]
            instruction = @ir[:instructions].find { |instr| instr[:name] == decl_name }
            instruction && instruction[:operation_type] == :element_wise
          else
            false
          end
        end
      end
      
      def compile_trait_evaluation(trait_eval_info)
        # Get the trait bindings directly
        trait_compilers = trait_eval_info[:traits].map do |trait_ref|
          @ir_compiler.send(:compile_operand, trait_ref)
        end
        
        lambda do |ctx|
          # Evaluate all traits and combine with AND logic
          trait_results = trait_compilers.map { |compiler| compiler.call(ctx) }
          
          # Handle both scalar and array results
          if trait_results.any? { |result| result.is_a?(Array) }
            # Element-wise AND - find primary array size
            primary_array = trait_results.find { |result| result.is_a?(Array) }
            return nil unless primary_array
            
            # For each element, AND all trait conditions
            primary_array.size.times.map do |i|
              trait_results.all? do |trait_result|
                element_value = trait_result.is_a?(Array) ? trait_result[i] : trait_result
                element_value
              end
            end
          else
            # Scalar AND
            trait_results.all? { |result| result }
          end
        end
      end

      def compile_element_wise_call_expression(call_expr)
        # Create element-wise operation compilation and delegate to LambdaFactory
        element_wise_compilation = {
          type: :element_wise_operation,
          function: call_expr[:function],
          operands: call_expr[:operands]
        }
        
        lambda_factory = LambdaFactory.new(@ir, @bindings)
        lambda_factory.build_element_wise_lambda(element_wise_compilation)
      end

      def determine_target_dimension(compilation)
        # Look at case analyses to find if any are element-wise
        case_analyses = compilation[:case_analyses] || []
        element_wise_cases = case_analyses.select { |analysis| analysis[:is_element_wise] }
        
        if element_wise_cases.any?
          # Find the primary dimension from element-wise cases
          # For now, assume dimension 1 (single array level)
          # TODO: Extract actual dimension from operand metadata
          1  
        else
          0  # Scalar cascade
        end
      end

      def build_element_wise_cascade_iterator(cascade_pairs)
        lambda do |ctx|
          # Evaluate all conditions and values once
          condition_results = cascade_pairs.map { |pair| pair[:condition].call(ctx) }
          value_results = cascade_pairs.map { |pair| pair[:value].call(ctx) }
          
          # DEBUG: Print what we got
          puts "DEBUG: condition_results = #{condition_results.inspect}" if ENV['CASCADE_DEBUG']
          puts "DEBUG: value_results = #{value_results.inspect}" if ENV['CASCADE_DEBUG']
          
          # Find primary array size from first array result
          primary_array = condition_results.find { |result| result.is_a?(Array) } ||
                         value_results.find { |result| result.is_a?(Array) }
          
          puts "DEBUG: primary_array = #{primary_array.inspect}" if ENV['CASCADE_DEBUG']
          return nil unless primary_array
          
          # For each element, evaluate cascade logic
          primary_array.size.times.map do |i|
            # Find the first matching condition for this element
            result_for_element = nil
            
            cascade_pairs.each_with_index do |pair, pair_idx|
              # Extract element condition (broadcast scalars)
              condition_result = condition_results[pair_idx]
              element_condition = condition_result.is_a?(Array) ? condition_result[i] : condition_result
              
              if element_condition
                # Extract element value (broadcast scalars)
                value_result = value_results[pair_idx]
                result_for_element = value_result.is_a?(Array) ? value_result[i] : value_result
                break  # Found matching condition, stop checking others
              end
            end
            
            result_for_element
          end
        end
      end

      def build_scalar_cascade_iterator(cascade_pairs)
        lambda do |ctx|
          cascade_pairs.each do |pair|
            condition_result = pair[:condition].call(ctx)
            return pair[:value].call(ctx) if condition_result
          end
          nil
        end
      end
    end
  end
end