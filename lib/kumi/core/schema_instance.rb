# frozen_string_literal: true

module Kumi
  module Core
    # A bound pair of <compiled schema + context>.  Immutable.
    #
    # Public API ----------------------------------------------------------
    #   instance.evaluate                # => full Hash of all bindings
    #   instance.evaluate(:tax_due, :rate)
    #   instance.slice(:tax_due)         # alias for evaluate(*keys)
    #   instance.explain(:tax_due)       # pretty trace string
    #   instance.input                   # original context (read‑only)

    class SchemaInstance
      attr_reader :compiled_schema, :metadata, :context

      def initialize(compiled_schema, metadata, context)
        @compiled_schema = compiled_schema # Kumi::Core::CompiledSchema
        @metadata = metadata # Frozen state hash
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

      def functions_used
        @metadata[:functions_required].to_a
      end

      # Update input values and clear affected cached computations
      def update(**changes)
        changes.each do |field, value|
          # Validate field exists
          raise ArgumentError, "unknown input field: #{field}" unless input_field_exists?(field)

          # Validate domain constraints
          validate_domain_constraint(field, value)

          # Update the input data
          @context[field] = value

          # Clear affected cached values using transitive closure by default
          if ENV["KUMI_SIMPLE_CACHE"] == "true"
            # Simple fallback: clear all cached values
            @context.clear_cache
          else
            # Default: selective cache clearing using precomputed transitive closure
            affected_keys = find_dependent_declarations_optimized(field)
            affected_keys.each { |key| @context.clear_cache(key) }
          end
        end

        self # Return self for chaining
      end

      private

      def input_field_exists?(field)
        # Check if field is declared in input block
        input_meta = @metadata[:input_metadata] || {}
        input_meta.key?(field) || @context.key?(field)
      end

      def validate_domain_constraint(field, value)
        input_meta = @metadata[:input_metadata] || {}
        field_meta = input_meta[field]
        return unless field_meta&.dig(:domain)

        domain = field_meta[:domain]
        return unless violates_domain?(value, domain)

        raise ArgumentError, "value #{value} is not in domain #{domain}"
      end

      def violates_domain?(value, domain)
        case domain
        when Range
          !domain.include?(value)
        when Array
          !domain.include?(value)
        when Proc
          # For Proc domains, we can't statically analyze
          false
        else
          false
        end
      end

      def find_dependent_declarations_optimized(field)
        # Use precomputed transitive closure for true O(1) lookup!
        transitive_dependents = @metadata[:dependents]
        return [] unless transitive_dependents

        # This is truly O(1) - just array lookup, no traversal needed
        transitive_dependents[field] || []
      end
    end
  end
end
