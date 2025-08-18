# frozen_string_literal: true

module Kumi
  module Registry
    class BaseBuilder
      def initialize(name)
        @name        = name
        @summary     = nil
        @signatures  = []
        @kernel      = nil
        @identity    = nil
        @dtypes      = nil
      end

      # DSL setters
      def summary(text)
        @summary = String(text)
      end
      
      def signature(*signatures)
        @signatures = signatures.flatten.map(&:to_s)
      end
      
      def identity(value)
        @identity = value
      end
      
      def kernel(&block)
        @kernel = block
      end
      
      def dtypes(types_hash)
        @dtypes = types_hash
      end

      private

      def missing_for(fields)
        fields.each_with_object([]) do |field, acc|
          acc << field if instance_variable_get(:"@#{field}").nil? || (field == :signatures && @signatures.empty?)
        end
      end

      def finalize_entry(kind:, defaults:)
        # Apply defaults when user omitted them
        @signatures = defaults[:signatures] if @signatures.empty?
        @dtypes ||= defaults[:dtypes]

        missing = missing_for([:kernel, :signatures])
        build_error!(missing) unless missing.empty?

        FunctionEntry.new(
          name:        @name,
          kind:        kind,
          signatures:  @signatures,
          kernel:      @kernel,
          variadic:    false,
          zip_policy:  defaults[:zip_policy],
          null_policy: defaults[:null_policy],
          identity:    @identity,
          summary:     @summary,
          dtypes:      @dtypes
        )
      end

      def build_error!(missing)
        hints = {
          kernel:      "Provide a lambda with `kernel { |*args| ... }`.",
          signatures:  "For each-wise, defaults apply; for aggregates, default is '(i)->()'. You can override via `signature(...)`.",
          identity:    "Aggregates should define an identity (e.g., 0 for sum) for empty inputs via `identity(...)`."
        }
        details = missing.map { |k| "- #{k}: #{hints[k]}" }.join("\n")
        raise BuildError.new(
          "Invalid function definition for `#{@name}`. Missing:\n#{details}",
          missing: missing,
          context: { name: @name }
        )
      end
    end
  end
end