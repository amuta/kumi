# frozen_string_literal: true

require 'delegate'

module Kumi
  module Parser
    # Wrapper that adds Sugar operators to FieldRef nodes (IR during DSL parsing)
    class SugarFieldRef < SimpleDelegator
      include Sugar::ExpressionOperators
      
      def initialize(field_ref)
        super(field_ref)
      end
      
      # Note: Don't override class method - that breaks to_ast_node detection
      
      # Make sure we respond correctly to is_a? checks
      def is_a?(klass)
        __getobj__.is_a?(klass) || super
      end
      
      # DSL builder context uses this to unwrap to pure AST node
      def to_ast_node
        __getobj__
      end

      # TEMPORARILY DISABLED: Method chaining to prevent infinite recursion
      # TODO: Implement safe method chaining without recursion issues
      # 
      # def method_missing(method_name, *args, &block)
      #   # Handle method chaining like input.text.length
      # end
      
      # def respond_to_missing?(method_name, include_private = false)
      #   # Method chaining support
      # end
    end
  end
end