# frozen_string_literal: true

module Kumi
  EvaluationWrapper = Struct.new(:ctx) do
    def initialize(ctx)
      super
      @__schema_cache__ = {} # memoization cache for bindings
    end

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
