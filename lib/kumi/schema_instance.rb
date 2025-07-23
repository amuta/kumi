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
      @schema   = compiled_schema          # Kumi::CompiledSchema
      @analysis = analysis                 # Analyzer result (for deps)
      @context  = context.freeze           # external Hash‑like
    end

    # Hash‑like read of one or many bindings
    def evaluate(*keys)
      if keys.empty?
        @schema.evaluate(@context)
      else
        @schema.evaluate(@context, *keys)
      end
    end
    alias slice evaluate

    # Convenience for the canonical audit trail
    def explain(key)
      @debugger.trace(@context, key)
    end

    def [](*keys)
      raise ArgumentError, "pass exactly one key" unless keys.size == 1

      evaluate(*keys).values.first
    end

    def input
      @context
    end
  end
end
