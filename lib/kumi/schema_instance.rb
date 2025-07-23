# frozen_string_literal: true

module Kumi
  # A bound pair of <compiled schema + context>.  Immutable.
  #
  # Public API ----------------------------------------------------------
  #   instance.evaluate                # => full Hash of all bindings
  #   instance.evaluate(:tax_due, :rate)
  #   instance.slice(:tax_due)         # alias for evaluate(*keys)
  #   instance.explain(:tax_due)       # pretty trace string
  #   instance.input                   # original context (read‑only)
  #
  class SchemaInstance
    def initialize(compiled_schema, analysis, context)
      @compiled_schema = compiled_schema # Kumi::CompiledSchema
      @analysis = analysis # Analyzer result (for deps)
      @context  = context.is_a?(EvaluationWrapper) ? context : EvaluationWrapper.new(context)
    end

    # Hash‑like read of one or many bindings
    def evaluate(*key_names)
      if key_names.empty?
        @compiled_schema.evaluate(@context)
      else
        @compiled_schema.evaluate(@context, *key_names)
      end
    end

    def slice(*key_names)
      return {} if key_names.empty?

      evaluate(*key_names)
    end

    def [](key_name)
      evaluate(key_name)[key_name]
    end

    def input
      @context
    end
  end
end
