# frozen_string_literal: true

module Kumi
  module Runtime
    class Run
      def initialize(program, input, mode:, input_metadata:, dependents:, declarations:)
        @program = program
        @input = input
        @mode = mode
        @input_metadata = input_metadata
        @declarations = declarations
        @dependents = dependents
        @cache = {}
      end

      def key?(name)
        @declarations.include? name
      end

      def get(name)
        unless @cache.key?(name)
          # Get the result in VM internal format
          vm_result = @program.eval_decl(name, @input, mode: :wrapped, declaration_cache: @cache)
          # Store VM format for cross-VM caching
          @cache[name] = vm_result
        end

        # Convert to requested format when returning
        vm_result = @cache[name]
        @mode == :wrapped ? vm_result : @program.unwrap(nil, vm_result)
      end

      def to_h
        slice(*@declarations)
      end

      def [](name)
        get(name)
      end

      def slice(*keys)
        return {} if keys.empty?

        keys.each_with_object({}) { |key, result| result[key] = get(key) }
      end

      def compiled_schema
        @program
      end

      def method_missing(sym, *args, **kwargs, &)
        return super unless args.empty? && kwargs.empty? && key?(sym)

        get(sym)
      end

      def respond_to_missing?(sym, priv = false)
        key?(sym) || super
      end

      def update(**changes)
        Set.new

        changes.each do |field, value|
          raise ArgumentError, "unknown input field: #{field}" unless input_field_exists?(field)

          validate_domain_constraint(field, value)

          @input[field] = value
          if (deps = @dependents[field])
            deps.each { |d| @cache.delete(d) }
          end
        end

        self
      end

      private

      def input_field_exists?(field)
        # Check if field is declared in input block
        @input_metadata.key?(field)
      end

      def validate_domain_constraint(field, value)
        field_meta = @input_metadata[field]
        return unless field_meta&.dig(:domain)

        domain = field_meta[:domain]
        return unless violates_domain?(value, domain)

        raise ArgumentError, "value #{value} is not in domain #{domain}"
      end

      def violates_domain?(value, domain)
        case domain
        when Range, Array
          !domain.include?(value)
        else
          false
        end
      end
    end
  end
end
