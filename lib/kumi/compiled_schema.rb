# frozen_string_literal: true

module Kumi
  class CompiledSchema
    def initialize(bindings) = @bindings = bindings

    # full evaluation
    def evaluate(data, *keys)
      return evaluate_traits(data).merge(evaluate_attributes(data)) if keys.empty?

      keys.each_with_object({}) do |name, hash|
        hash[name] = evaluate_binding(name, data)
      end
    end

    # only traits
    def traits(**data) = evaluate_traits(data)

    # only attributes
    def attributes(**data) = evaluate_attributes(data)

    # single binding
    def evaluate_binding(name, data)
      raise Kumi::Errors::RuntimeError, "No binding named #{name}" unless @bindings.key?(name)

      @bindings[name][1].call(data)
    end

    private

    def evaluate_traits(data)
      validate_ctx(data)
      filter_by(:trait).transform_values { |fn| fn.call(data) }
    end

    def evaluate_attributes(data)
      validate_ctx(data)
      filter_by(:attr).transform_values { |fn| fn.call(data) }
    end

    def filter_by(kind)
      @bindings.each_with_object({}) do |(k, (knd, fn)), h|
        h[k] = fn if knd == kind
      end
    end

    def validate_ctx(ctx)
      return if ctx.is_a?(Hash) ||
                (ctx.respond_to?(:key?) && ctx.respond_to?(:[]))

      raise Kumi::Errors::RuntimeError,
            "Data context should be Hash-like (respond to :key? and :[])"
    end
  end
end
