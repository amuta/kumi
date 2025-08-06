# frozen_string_literal: true

module Kumi
  module Core
    EvaluationWrapper = Struct.new(:ctx) do
      def initialize(ctx)
        super
        @__schema_cache__ = {} # memoization cache for bindings
      end

      # Delegate all hash-like operations directly to ctx
      def [](key)
        ctx[key]
      end

      def []=(key, value)
        ctx[key] = value
      end

      def keys
        ctx.keys
      end

      def key?(key)
        ctx.key?(key)
      end

      def each(&block)
        ctx.each(&block)
      end

      def each_with_object(obj, &block)
        ctx.each_with_object(obj, &block)
      end

      def map(&block)
        ctx.map(&block)
      end

      def is_a?(klass)
        # Allow EvaluationWrapper to appear as Hash for accessor compatibility
        klass == Hash || super
      end

      def clear
        @__schema_cache__.clear
      end

      def clear_cache(*keys)
        if keys.empty?
          @__schema_cache__.clear
        else
          keys.each { |key| @__schema_cache__.delete(key) }
        end
      end
    end
  end
end
