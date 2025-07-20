# frozen_string_literal: true

module Kumi
  module Parser
    class DslProxy
      DSL_METHODS = %i[
        value predicate input
        ref literal fn
      ].freeze

      def initialize(context)
        @context = context
      end

      DSL_METHODS.each do |meth|
        define_method(meth) do |*args, **kwargs, &blk|
          # grab exactly where the user invoked `attribute`, `fn`, etc.
          c = caller_locations(1, 1).first
          @context.last_loc = Syntax::Location.new(
            file: c.path,
            line: c.lineno,
            column: 0
          )
          @context.public_send(meth, *args, **kwargs, &blk)
        end
      end

      def method_missing(method_name, *args, &block)
        if args.empty? && !block_given?
          c = caller_locations(1, 1).first
          @context.last_loc = Syntax::Location.new(
            file: c.path,
            line: c.lineno,
            column: 0
          )
          @context.public_send(method_name, *args, &block)
        else
          super
        end
      end

      def respond_to_missing?(method_name, include_private = false)
        @context.respond_to_missing?(method_name, include_private)
      end
    end
  end
end
