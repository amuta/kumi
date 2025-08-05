# frozen_string_literal: true

module Kumi
  module Core
    # Base compiler class with shared compilation logic between Ruby and JS compilers
    class CompilerBase
      # Map node classes to compiler methods
      DISPATCH = {
        Kumi::Syntax::Literal => :compile_literal,
        Kumi::Syntax::InputReference => :compile_field_node,
        Kumi::Syntax::InputElementReference => :compile_element_field_reference,
        Kumi::Syntax::DeclarationReference => :compile_binding_node,
        Kumi::Syntax::ArrayExpression => :compile_list,
        Kumi::Syntax::CallExpression => :compile_call,
        Kumi::Syntax::CascadeExpression => :compile_cascade
      }.freeze

      def initialize(syntax_tree, analyzer_result)
        @schema = syntax_tree
        @analysis = analyzer_result
      end

      # Shared compilation logic

      def build_index
        @index = {}
        @schema.attributes.each { |a| @index[a.name] = a }
        @schema.traits.each     { |t| @index[t.name] = t }
      end

      def determine_operation_mode_for_path(_path)
        # Use pre-computed operation mode from analysis
        compilation_meta = @analysis.state[:broadcasts]&.dig(:compilation_metadata, @current_declaration)
        compilation_meta&.dig(:operation_mode) || :broadcast
      end

      def vectorized_operation?(expr)
        # Use pre-computed vectorization decision from analysis
        compilation_meta = @analysis.state[:broadcasts]&.dig(:compilation_metadata, @current_declaration)
        return false unless compilation_meta

        # Check if current declaration is vectorized
        if compilation_meta[:is_vectorized]
          # For vectorized declarations, check if this specific operation should be vectorized
          vectorized_ops = @analysis.state[:broadcasts][:vectorized_operations] || {}
          current_decl_info = vectorized_ops[@current_declaration]

          # For cascade declarations, check individual operations within them
          return true if current_decl_info && current_decl_info[:operation] == expr.fn_name

          # For cascade_with_vectorized_conditions_or_results, allow nested operations
          return true if current_decl_info && current_decl_info[:source] == :cascade_with_vectorized_conditions_or_results

          # Check if this is a direct vectorized operation
          return true if current_decl_info && current_decl_info[:operation]
        end

        # Fallback: Reduction functions are NOT vectorized operations - they consume arrays
        return false if Kumi::Registry.reducer?(expr.fn_name)

        # Use pre-computed vectorization context for remaining cases
        compilation_meta.dig(:vectorization_context, :needs_broadcasting) || false
      end

      def is_cascade_vectorized?(_expr)
        # Use metadata to determine if this cascade is vectorized
        broadcast_meta = @analysis.state[:broadcasts]
        cascade_info = @current_declaration && broadcast_meta&.dig(:vectorized_operations, @current_declaration)
        cascade_info && cascade_info[:source] == :cascade_with_vectorized_conditions_or_results
      end

      def get_cascade_compilation_metadata
        compilation_meta = @analysis.state[:broadcasts]&.dig(:compilation_metadata, @current_declaration)
        cascade_info = compilation_meta&.dig(:cascade_info) || {}
        [compilation_meta, cascade_info]
      end

      def get_cascade_strategy
        @analysis.state[:broadcasts][:cascade_strategies][@current_declaration]
      end

      def get_function_call_strategy
        compilation_meta = @analysis.state[:broadcasts]&.dig(:compilation_metadata, @current_declaration)
        compilation_meta&.dig(:function_call_strategy) || {}
      end

      def needs_flattening?
        function_strategy = get_function_call_strategy
        function_strategy[:flattening_required]
      end

      def get_flattening_info
        @analysis.state[:broadcasts][:flattening_declarations][@current_declaration]
      end

      def get_flatten_argument_indices
        compilation_meta = @analysis.state[:broadcasts]&.dig(:compilation_metadata, @current_declaration)
        compilation_meta&.dig(:function_call_strategy, :flatten_argument_indices) || []
      end

      # Dispatch to the appropriate compile_* method
      def compile_expr(expr)
        method = DISPATCH.fetch(expr.class)
        send(method, expr)
      end

      # Abstract methods to be implemented by subclasses
      def compile_literal(expr)
        raise NotImplementedError, "Subclasses must implement compile_literal"
      end

      def compile_field_node(expr)
        raise NotImplementedError, "Subclasses must implement compile_field_node"
      end

      def compile_element_field_reference(expr)
        raise NotImplementedError, "Subclasses must implement compile_element_field_reference"
      end

      def compile_binding_node(expr)
        raise NotImplementedError, "Subclasses must implement compile_binding_node"
      end

      def compile_list(expr)
        raise NotImplementedError, "Subclasses must implement compile_list"
      end

      def compile_call(expr)
        raise NotImplementedError, "Subclasses must implement compile_call"
      end

      def compile_cascade(expr)
        raise NotImplementedError, "Subclasses must implement compile_cascade"
      end
    end
  end
end
