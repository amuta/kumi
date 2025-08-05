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

        %i[integer float string boolean any scalar].each do |type_name|
          define_method(type_name) do |name, type: nil, domain: nil|
            actual_type = type || (type_name == :scalar ? :any : type_name)
            @context.inputs << Kumi::Syntax::InputDeclaration.new(name, domain, actual_type, [], nil, loc: @context.current_location)
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
          allowed_methods = "'key', 'integer', 'float', 'string', 'boolean', 'any', 'scalar', 'array', 'hash', and 'element'"
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
          @context.inputs << Kumi::Syntax::InputDeclaration.new(field_name, domain, array_type, [], :object, loc: @context.current_location)
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
          children, elem_type, using_elements = collect_array_children(&block)

          # Create the InputDeclaration with children and access_mode
          access_mode = using_elements ? :element : :object
          @context.inputs << Kumi::Syntax::InputDeclaration.new(
            field_name,
            domain,
            :array,
            children,
            access_mode,
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

          # Determine element type based on what was declared
          elem_type = determine_element_type(nested_builder, nested_inputs)
          
          # Check if element() was used
          using_elements = nested_builder.instance_variable_get(:@using_elements) || false

          [nested_inputs, elem_type, using_elements]
        end

        def determine_element_type(builder, inputs)
          # Since element() always creates named children now, 
          # we just use the standard logic
          if inputs.any?
            # If fields were declared, it's a hash/object structure
            :hash
          else
            # No fields declared, default to :any
            :any
          end
        end


        def primitive_element_type?(elem_type)
          %i[string integer float boolean bool any symbol].include?(elem_type)
        end

        # New method: element() declaration - always requires a name
        def element(type_spec, name, &block)
          if block_given?
            # Named element with nested structure: element(:array, :rows) do ... end
            # These don't set @using_elements because they create complex structures
            case type_spec
            when :array
              create_array_field_with_block(name, {}, &block)
            when :object
              # Create nested object structure
              create_object_element(name, &block)
            else
              raise_syntax_error("element(#{type_spec.inspect}, #{name.inspect}) with block only supports :array or :object types", location: @context.current_location)
            end
          else
            # Named primitive element: element(:boolean, :active)
            # Only primitive elements mark the parent as using element access
            @using_elements = true
            @context.inputs << Kumi::Syntax::InputDeclaration.new(name, nil, type_spec, [], nil, loc: @context.current_location)
          end
        end

        def create_object_element(name, &block)
          # Similar to create_array_field_with_block but for objects
          children, _ = collect_array_children(&block)
          @context.inputs << Kumi::Syntax::InputDeclaration.new(name, nil, :object, children, nil, loc: @context.current_location)
        end
      end
    end
  end
end
