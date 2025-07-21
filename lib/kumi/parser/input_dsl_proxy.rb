# frozen_string_literal: true

module Kumi
  module Parser
    # Proxy class for the input block DSL
    # Only exposes the key() method for field declarations
    class InputDslProxy
      include Syntax

      def initialize(context)
        @context = context
      end

      def key(name, type: :any, domain: nil)
        # Normalize the type using the simplified type system
        begin
          normalized_type = Kumi::Types.normalize(type)
        rescue ArgumentError => e
          @context.raise_error("Invalid type for input `#{name}`: #{e.message}", @context.current_location)
        end

        @context.inputs << FieldDecl.new(name, domain, normalized_type, loc: @context.current_location)
      end

      # Type-specific DSL methods
      def integer(name, domain: nil)
        @context.inputs << FieldDecl.new(name, domain, :integer, loc: @context.current_location)
      end

      def float(name, domain: nil)
        @context.inputs << FieldDecl.new(name, domain, :float, loc: @context.current_location)
      end

      def string(name, domain: nil)
        @context.inputs << FieldDecl.new(name, domain, :string, loc: @context.current_location)
      end

      def boolean(name, domain: nil)
        @context.inputs << FieldDecl.new(name, domain, :boolean, loc: @context.current_location)
      end

      def any(name, domain: nil)
        @context.inputs << FieldDecl.new(name, domain, :any, loc: @context.current_location)
      end

      def array(name_or_elem_type, **kwargs)
        # Check if any keyword arguments were provided
        if kwargs.any?
          # New DSL usage: array :field_name, elem: {...}, domain: ...
          field_name = name_or_elem_type
          elem_spec = kwargs[:elem]
          domain = kwargs[:domain]

          elem_type = elem_spec.is_a?(Hash) && elem_spec[:type] ? elem_spec[:type] : :any

          begin
            array_type = Kumi::Types.array(elem_type)
          rescue ArgumentError => e
            @context.raise_error("Invalid element type for array `#{field_name}`: #{e.message}", @context.current_location)
          end

          @context.inputs << FieldDecl.new(field_name, domain, array_type, loc: @context.current_location)
        else
          # Old helper usage: array(:elem_type)
          Kumi::Types.array(name_or_elem_type)
        end
      end

      def hash(name_or_key_type, val_type = nil, **kwargs)
        return Kumi::Types.hash(name_or_key_type, val_type) unless val_type.nil?

        create_hash_field(name_or_key_type, kwargs)
      end

      private

      def create_hash_field(field_name, options)
        key_spec = options[:key]
        # support both :val and :value aliases for value specification
        val_spec = options[:val] || options[:value]
        domain   = options[:domain]

        key_type = extract_type(key_spec)
        val_type = extract_type(val_spec)

        hash_type = create_hash_type(field_name, key_type, val_type)
        @context.inputs << FieldDecl.new(field_name, domain, hash_type, loc: @context.current_location)
      end

      def extract_type(spec)
        spec.is_a?(Hash) && spec[:type] ? spec[:type] : :any
      end

      def create_hash_type(field_name, key_type, val_type)
        Kumi::Types.hash(key_type, val_type)
      rescue ArgumentError => e
        @context.raise_error("Invalid types for hash `#{field_name}`: #{e.message}", @context.current_location)
      end

      def method_missing(method_name, *_args)
        allowed_methods = "'key', 'integer', 'float', 'string', 'boolean', 'any', 'array', and 'hash'"
        @context.raise_error("Unknown method '#{method_name}' in input block. Only #{allowed_methods} are allowed.",
                             @context.current_location)
      end

      def respond_to_missing?(_method_name, _include_private = false)
        false
      end
    end
  end
end
