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
          @context.inputs << Kumi::Syntax::InputDeclaration.new(name, domain, normalized_type, [], nil, loc: @context.current_location)
        end

        %i[integer float decimal string boolean any scalar].each do |type_name|
          define_method(type_name) do |name, type: nil, domain: nil|
            actual_type = type || (type_name == :scalar ? :any : type_name)
            @context.inputs << Kumi::Syntax::InputDeclaration.new(name, domain, actual_type, [], nil, loc: @context.current_location)
          end
        end

        def array(name_or_elem_type, **kwargs, &)
          if block_given?
            create_array_field_with_block(name_or_elem_type, kwargs, &)
          elsif kwargs.any?
            create_array_field(name_or_elem_type, kwargs)
          elsif name_or_elem_type.is_a?(Symbol)
            # A bare `array :xs` input with no block names the array but not its
            # element. Kumi maps over arrays by default, so the element MUST be
            # named — that name is the per-element binding you reference in the
            # body. Guide the user to the one-child form.
            raise_syntax_error(
              "Array input '#{name_or_elem_type}' needs a block that names its element. " \
              "Kumi maps over arrays by default, so the element needs a name to map onto, e.g.\n" \
              "  array :#{name_or_elem_type} do\n" \
              "    float :value          # scalar element, referenced as input.#{name_or_elem_type}.value\n" \
              "  end\n" \
              "Use a `hash` child when each element has several fields, " \
              "or a nested `array` child for an array of arrays.",
              location: @context.current_location
            )
          else
            Kumi::Core::Types.array(name_or_elem_type)
          end
        end

        def hash(name_or_key_type, val_type = nil, **kwargs, &)
          if block_given?
            create_hash_field_with_block(name_or_key_type, kwargs, &)
          elsif val_type.nil? && name_or_key_type.is_a?(Symbol)
            create_bare_hash_field(name_or_key_type, kwargs)
          elsif val_type.nil?
            create_hash_field(name_or_key_type, kwargs)
          else
            Kumi::Core::Types.hash(name_or_key_type, val_type)
          end
        end

        def method_missing(method_name, *_args)
          allowed_methods = "'key', 'integer', 'float', 'decimal', 'string', 'boolean', 'any', 'scalar', 'array', 'hash', and 'element'"
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
          @context.inputs << Kumi::Syntax::InputDeclaration.new(field_name, domain, array_type, [], :field, loc: @context.current_location)
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
          @context.inputs << Kumi::Syntax::InputDeclaration.new(field_name, domain, hash_type, [], nil, loc: @context.current_location)
        end

        def create_bare_hash_field(field_name, options)
          unknown = options.keys - [:domain]
          unless unknown.empty?
            raise_syntax_error(
              "hash input '#{field_name}' only supports `domain:` without a block. " \
              "Use `hash :#{field_name} do ... end` for declared fields.",
              location: @context.current_location
            )
          end

          @context.inputs << Kumi::Syntax::InputDeclaration.new(field_name, options[:domain], :hash, [], nil, loc: @context.current_location)
        end

        def extract_type(spec)
          spec.is_a?(Hash) && spec[:type] ? spec[:type] : :any
        end

        def create_hash_type(field_name, key_type, val_type)
          Kumi::Core::Types.hash(key_type, val_type)
        rescue ArgumentError => e
          raise_syntax_error("Invalid types for hash `#{field_name}`: #{e.message}", location: @context.current_location)
        end

        def create_array_field_with_block(field_name, options, &)
          domain = options[:domain]
          index_name = options[:index]
          unknown = options.keys - %i[domain index]
          unless unknown.empty?
            raise_syntax_error(
              "unknown option(s) for array input '#{field_name}': #{unknown.map { |key| "#{key}:" }.join(', ')}",
              location: @context.current_location
            )
          end
          if index_name && !index_name.is_a?(Symbol)
            raise_syntax_error("array input '#{field_name}' index: must be a Symbol", location: @context.current_location)
          end

          children = collect_array_children(&)
          @context.inputs << Kumi::Syntax::InputDeclaration.new(
            field_name,
            domain,
            :array,
            children,
            index_name,
            loc: @context.current_location
          )
        end

        # Run a child-declaration block against a fresh nested builder and return
        # the declarations it collected.
        def collect_array_children(&)
          nested_inputs = []
          nested_context = NestedInput.new(nested_inputs, @context.current_location)
          InputBuilder.new(nested_context).instance_eval(&)
          nested_inputs
        end

        # `element(type, :name)` declares a named child. With a block it nests an
        # array or object; without one it is a named primitive element.
        def element(type_spec, name, &)
          if block_given?
            case type_spec
            when :array
              create_array_field_with_block(name, {}, &)
            when :field
              create_object_element(name, &)
            else
              raise_syntax_error("element(#{type_spec.inspect}, #{name.inspect}) with block only supports :array or :field types",
                                 location: @context.current_location)
            end
          else
            @context.inputs << Kumi::Syntax::InputDeclaration.new(name, nil, type_spec, [], nil, loc: @context.current_location)
          end
        end

        def create_object_element(name, &)
          children = collect_array_children(&)
          @context.inputs << Kumi::Syntax::InputDeclaration.new(name, nil, :field, children, nil, loc: @context.current_location)
        end

        def create_hash_field_with_block(field_name, options, &)
          domain = options[:domain]
          children = collect_array_children(&)

          # `index` is only consumed downstream for array containers (the access
          # planner reads define_index only when container == :array), so a hash
          # carries no index. Leave it nil to match the text frontend's AST.
          @context.inputs << Kumi::Syntax::InputDeclaration.new(
            field_name,
            domain,
            :hash,
            children,
            nil,
            loc: @context.current_location
          )
        end
      end
    end
  end
end
