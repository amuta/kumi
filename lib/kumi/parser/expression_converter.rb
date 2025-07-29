# frozen_string_literal: true

module Kumi
  module Parser
    # Converts Ruby objects and DSL expressions into AST nodes
    # This is the bridge between Ruby's native types and Kumi's syntax tree
    class ExpressionConverter
      include Syntax
      include ErrorReporting

      # Use the same literal types as Sugar module to avoid duplication
      LITERAL_TYPES = Sugar::LITERAL_TYPES

      def initialize(context)
        @context = context
      end

      # Convert any Ruby object into a syntax node
      # @param obj [Object] The object to convert
      # @return [Syntax::Node] The corresponding AST node
      def ensure_syntax(obj)
        case obj
        when *LITERAL_TYPES
          create_literal(obj)
        when Array
          create_list(obj)
        when Syntax::Node
          obj
        else
          handle_custom_object(obj)
        end
      end

      # Create a reference to another declaration
      # @param name [Symbol] The name to reference
      # @return [Syntax::DeclarationReference] Reference node
      def ref(name)
        validate_reference_name(name)
        Kumi::Syntax::DeclarationReference.new(name, loc: current_location)
      end

      # Create a literal value node
      # @param value [Object] The literal value
      # @return [Syntax::Literal] Literal node
      def literal(value)
        Kumi::Syntax::Literal.new(value, loc: current_location)
      end

      # Create a function call expression
      # @param fn_name [Symbol] The function name
      # @param args [Array] The function arguments
      # @return [Syntax::CallExpression] Function call node
      def fn(fn_name, *args)
        validate_function_name(fn_name)
        expr_args = convert_arguments(args)
        Kumi::Syntax::CallExpression.new(fn_name, expr_args, loc: current_location)
      end

      # Access the input proxy for field references
      # @return [InputProxy] Proxy for input field access
      def input
        InputProxy.new(@context)
      end

      # Raise a syntax error with location information
      # @param message [String] Error message
      # @param location [Location] Error location
      def raise_error(message, location)
        raise_syntax_error(message, location: location)
      end

      private

      def create_literal(value)
        Kumi::Syntax::Literal.new(value, loc: current_location)
      end

      def create_list(array)
        elements = array.map { |element| ensure_syntax(element) }
        Kumi::Syntax::ArrayExpression.new(elements, loc: current_location)
      end

      def handle_custom_object(obj)
        if obj.respond_to?(:to_ast_node)
          obj.to_ast_node
        else
          raise_invalid_expression_error(obj)
        end
      end

      def validate_reference_name(name)
        unless name.is_a?(Symbol)
          raise_syntax_error(
            "Reference name must be a symbol, got #{name.class}",
            location: current_location
          )
        end
      end

      def validate_function_name(fn_name)
        unless fn_name.is_a?(Symbol)
          raise_syntax_error(
            "Function name must be a symbol, got #{fn_name.class}",
            location: current_location
          )
        end
      end

      def convert_arguments(args)
        args.map { |arg| ensure_syntax(arg) }
      end

      def raise_invalid_expression_error(obj)
        raise_syntax_error(
          "Cannot convert #{obj.class} to AST node. " \
          "Value: #{obj.inspect}",
          location: current_location
        )
      end

      def current_location
        @context.current_location
      end
    end
  end
end