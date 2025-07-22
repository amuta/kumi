# frozen_string_literal: true

module Kumi
  module Parser
    class InputBuilder
      include Syntax
      include ErrorReporting

      def initialize(context)
        @context = context
      end

      def key(name, type: :any, domain: nil)
        normalized_type = normalize_type(type, name)
        @context.inputs << FieldDecl.new(name, domain, normalized_type, loc: @context.current_location)
      end

      %i[integer float string boolean any].each do |type_name|
        define_method(type_name) do |name, domain: nil|
          @context.inputs << FieldDecl.new(name, domain, type_name, loc: @context.current_location)
        end
      end

      def array(name_or_elem_type, **kwargs)
        if kwargs.any?
          create_array_field(name_or_elem_type, kwargs)
        else
          Kumi::Types.array(name_or_elem_type)
        end
      end

      def hash(name_or_key_type, val_type = nil, **kwargs)
        return Kumi::Types.hash(name_or_key_type, val_type) unless val_type.nil?

        create_hash_field(name_or_key_type, kwargs)
      end

      def method_missing(method_name, *_args)
        allowed_methods = "'key', 'integer', 'float', 'string', 'boolean', 'any', 'array', and 'hash'"
        raise_syntax_error("Unknown method '#{method_name}' in input block. Only #{allowed_methods} are allowed.",
                           location: @context.current_location)
      end

      def respond_to_missing?(_method_name, _include_private = false)
        false
      end

      private

      def normalize_type(type, name)
        Kumi::Types.normalize(type)
      rescue ArgumentError => e
        raise_syntax_error("Invalid type for input `#{name}`: #{e.message}", location: @context.current_location)
      end

      def create_array_field(field_name, options)
        elem_spec = options[:elem]
        domain = options[:domain]
        elem_type = elem_spec.is_a?(Hash) && elem_spec[:type] ? elem_spec[:type] : :any

        array_type = create_array_type(field_name, elem_type)
        @context.inputs << FieldDecl.new(field_name, domain, array_type, loc: @context.current_location)
      end

      def create_array_type(field_name, elem_type)
        Kumi::Types.array(elem_type)
      rescue ArgumentError => e
        raise_syntax_error("Invalid element type for array `#{field_name}`: #{e.message}", location: @context.current_location)
      end

      def create_hash_field(field_name, options)
        key_spec = options[:key]
        val_spec = options[:val] || options[:value]
        domain = options[:domain]

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
        raise_syntax_error("Invalid types for hash `#{field_name}`: #{e.message}", location: @context.current_location)
      end
    end
  end
end
