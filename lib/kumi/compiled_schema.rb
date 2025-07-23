# frozen_string_literal: true

module Kumi
  class CompiledSchema
    attr_reader :bindings

    def initialize(bindings)
      @bindings = bindings.freeze
    end

    def evaluate(ctx, *key_names)
      target_keys = key_names.empty? ? @bindings.keys : validate_keys(key_names)

      target_keys.each_with_object({}) do |key, result|
        result[key] = evaluate_binding(key, ctx)
      end
    end

    def evaluate_binding(key, ctx)
      memo = ctx.instance_variable_get(:@__schema_cache__)
      return memo[key] if memo&.key?(key)

      value = @bindings[key][1].call(ctx)
      memo[key] = value if memo
      value
    end

    private

    def hash_like?(obj)
      obj.respond_to?(:key?) && obj.respond_to?(:[])
    end

    def validate_keys(keys)
      unknown_keys = keys - @bindings.keys
      return keys if unknown_keys.empty?

      raise Kumi::Errors::RuntimeError, "No binding named #{unknown_keys.first}"
    end
  end
end
