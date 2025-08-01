# frozen_string_literal: true

module Kumi
  module Core
    module RubyParser
      class InputBuilder
        include Syntax
        include ErrorReporting

        def initialize(context)
          @context = context
        end

        def key(name, type: :any, domain: nil)
          normalized_type = normalize_type(type, name)
          @context.inputs << Kumi::Syntax::InputDeclaration.new(name, domain, normalized_type, [], loc: @context.current_location)
        end

        %i[integer float string boolean any scalar].each do |type_name|
          define_method(type_name) do |name, type: nil, domain: nil|
            actual_type = type || (type_name == :scalar ? :any : type_name)
            @context.inputs << Kumi::Syntax::InputDeclaration.new(name, domain, actual_type, [], loc: @context.current_location)
          end
        end

        def array(name_or_elem_type, **kwargs, &block)
          if block_given?
            create_array_field_with_block(name_or_elem_type, kwargs, &block)
          elsif kwargs.any?
            create_array_field(name_or_elem_type, kwargs)
          else
            Kumi::Core::Types.array(name_or_elem_type)
          end
        end

        def hash(name_or_key_type, val_type = nil, **kwargs)
          return Kumi::Core::Types.hash(name_or_key_type, val_type) unless val_type.nil?

          create_hash_field(name_or_key_type, kwargs)
        end

        def method_missing(method_name, *_args)
          allowed_methods = "'key', 'integer', 'float', 'string', 'boolean', 'any', 'scalar', 'array', and 'hash'"
          raise_syntax_error("Unknown method '#{method_name}' in input block. Only #{allowed_methods} are allowed.",
                             location: @context.current_location)
        end

        def respond_to_missing?(_method_name, _include_private = false)
          false
        end

        private

        def normalize_type(type, name)
          Kumi::Core::Types.normalize(type)
        rescue ArgumentError => e
          raise_syntax_error("Invalid type for input `#{name}`: #{e.message}", location: @context.current_location)
        end

        def create_array_field(field_name, options)
          elem_spec = options[:elem]
          domain = options[:domain]
          elem_type = elem_spec.is_a?(Hash) && elem_spec[:type] ? elem_spec[:type] : :any

          array_type = create_array_type(field_name, elem_type)
          @context.inputs << Kumi::Syntax::InputDeclaration.new(field_name, domain, array_type, [], loc: @context.current_location)
        end

        def create_array_type(field_name, elem_type)
          Kumi::Core::Types.array(elem_type)
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
          @context.inputs << Kumi::Syntax::InputDeclaration.new(field_name, domain, hash_type, [], loc: @context.current_location)
        end

        def extract_type(spec)
          spec.is_a?(Hash) && spec[:type] ? spec[:type] : :any
        end

        def create_hash_type(field_name, key_type, val_type)
          Kumi::Core::Types.hash(key_type, val_type)
        rescue ArgumentError => e
          raise_syntax_error("Invalid types for hash `#{field_name}`: #{e.message}", location: @context.current_location)
        end

        def create_array_field_with_block(field_name, options, &block)
          domain = options[:domain]

          # Collect children by creating a nested context
          children = collect_array_children(&block)

          # Create the InputDeclaration with children
          @context.inputs << Kumi::Syntax::InputDeclaration.new(
            field_name,
            domain,
            :array,
            children,
            loc: @context.current_location
          )
        end

        def collect_array_children(&block)
          # Create a temporary nested context to collect children
          nested_inputs = []
          nested_context = NestedInput.new(nested_inputs, @context.current_location)
          nested_builder = InputBuilder.new(nested_context)

          # Execute the block in the nested context
          nested_builder.instance_eval(&block)

          nested_inputs
        end
      end
    end
  end
end
