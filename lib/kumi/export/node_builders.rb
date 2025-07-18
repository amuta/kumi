# frozen_string_literal: true

module Kumi
  module Export
    module NodeBuilders
      def build_root(data, node_class)
        inputs = data[:inputs].map { |input_data| build_node(input_data) }
        attributes = data[:attributes].map { |attr_data| build_node(attr_data) }
        traits = data[:traits].map { |trait_data| build_node(trait_data) }

        node_class.new(inputs, attributes, traits)
      end

      def build_field_declaration(data, node_class)
        name = restore_name_type(data[:name], data[:name_type])
        type = deserialize_type(data[:field_type])
        domain = deserialize_domain(data[:domain])

        # Match the Struct signature of FieldDecl: (name, domain, type)
        node_class.new(name, domain, type)
      end

      def build_attribute_declaration(data, node_class)
        name = restore_name_type(data[:name], data[:name_type])
        expression = build_node(data[:expression])

        node_class.new(name, expression)
      end

      def build_trait_declaration(data, node_class)
        name = restore_name_type(data[:name], data[:name_type])
        expression = build_node(data[:expression])

        node_class.new(name, expression)
      end

      def build_call_expression(data, node_class)
        function_name = restore_name_type(data[:function_name], data[:function_name_type])
        arguments = data[:arguments].map { |arg_data| build_node(arg_data) }

        node_class.new(function_name, arguments)
      end

      def build_literal(data, node_class)
        value = data[:value]

        # Restore proper Ruby type if needed
        value = coerce_to_type(value, data[:ruby_type]) if data[:ruby_type] && value.is_a?(String)

        node_class.new(value)
      end

      def build_field_reference(data, node_class)
        field_name = restore_name_type(data[:field_name], data[:name_type])
        node_class.new(field_name)
      end

      def build_binding_reference(data, node_class)
        binding_name = restore_name_type(data[:binding_name], data[:name_type])
        node_class.new(binding_name)
      end

      def build_list_expression(data, node_class)
        elements = data[:elements].map { |element_data| build_node(element_data) }
        node_class.new(elements)
      end

      def build_cascade_expression(data, node_class)
        cases = data[:cases].map { |case_data| build_node(case_data) }
        node_class.new(cases)
      end

      def build_when_case_expression(data, node_class)
        condition = build_node(data[:condition])
        result = build_node(data[:result])
        node_class.new(condition, result)
      end

      private

      def deserialize_type(type_data)
        # Handle simple types that weren't serialized with the new format
        return type_data unless type_data.is_a?(Hash) && type_data.key?(:type)

        case type_data[:type]
        when "symbol"
          type_data[:value].to_sym
        when "array"
          { array: deserialize_type(type_data[:element_type]) }
        when "hash"
          { hash: [deserialize_type(type_data[:key_type]), deserialize_type(type_data[:value_type])] }
        when "literal"
          type_data[:value]
        else
          type_data[:value]
        end
      end

      def build_node(node_data)
        type_name = node_data[:type]
        node_class = NodeRegistry.class_for_type(type_name)

        build_method = "build_#{type_name}"
        raise Kumi::Export::DeserializationError, "No builder for type: #{type_name}" unless respond_to?(build_method, true)

        send(build_method, node_data, node_class)
      end

      def deserialize_domain(domain_data)
        return nil unless domain_data

        case domain_data[:type]
        when "range"
          min, max = domain_data.values_at(:min, :max)
          domain_data[:exclude_end] ? (min...max) : (min..max)
        when "array"
          domain_data[:values]
        when "custom"
          # For custom domains, we might need to eval or have a registry
          domain_data[:value]
        end
      end

      def coerce_to_type(value, type_name)
        case type_name
        when "Integer" then value.to_i
        when "Float" then value.to_f
        when "Symbol" then value.to_sym
        else value
        end
      end

      def restore_name_type(name_string, name_type)
        case name_type
        when "Symbol" then name_string.to_sym
        when "String" then name_string.to_s
        else name_string
        end
      end
    end
  end
end
