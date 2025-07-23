# frozen_string_literal: true

module Kumi
  EvaluationWrapper = Struct.new(:ctx) do
    def initialize(ctx)
      @ctx = ctx
      @__schema_cache__ = {} # memoization cache for bindings
    end

    def [](key)
      @ctx[key]
    end

    def keys
      @ctx.keys
    end

    def key?(key)
      @ctx.key?(key)
    end
  end
end
