# frozen_string_literal: true

module Kumi
  module Core
    module Export
      module NodeSerializers
        # Root node: top-level container
        def serialize_root(node)
          {
            type: "root",
            inputs: node.inputs.map { |input| serialize_node(input) },
            attributes: node.attributes.map { |attr| serialize_node(attr) },
            traits: node.traits.map { |trait| serialize_node(trait) }
          }
        end

        # Field Declaration: preserves type info for analyzer
        def serialize_field_declaration(node)
          {
            name: node.name.to_s,
            name_type: node.name.class.name,
            field_type: serialize_type(node.type),
            domain: serialize_domain(node.domain)
          }
        end

        # Attribute Declaration: preserves name and expression tree
        def serialize_attribute_declaration(node)
          {
            name: node.name.to_s,
            name_type: node.name.class.name,
            expression: serialize_node(node.expression)
          }
        end

        # Trait Declaration: preserves name and expression tree
        def serialize_trait_declaration(node)
          {
            name: node.name.to_s,
            name_type: node.name.class.name,
            expression: serialize_node(node.expression)
          }
        end

        # Call Expression: critical for dependency analysis
        def serialize_call_expression(node)
          {
            function_name: node.fn_name.to_s,
            function_name_type: node.fn_name.class.name,
            arguments: node.args.map { |arg| serialize_node(arg) }
          }
        end

        # Literal: preserve exact value and Ruby type
        def serialize_literal(node)
          {
            value: node.value,
            ruby_type: node.value.class.name
          }
        end

        # Field Reference: critical for dependency resolution
        def serialize_field_reference(node)
          {
            field_name: node.name.to_s,
            name_type: node.name.class.name
          }
        end

        # DeclarationReference Reference: critical for dependency resolution
        def serialize_binding_reference(node)
          {
            binding_name: node.name.to_s,
            name_type: node.name.class.name
          }
        end

        # List Expression: preserve order and elements
        def serialize_list_expression(node)
          {
            elements: node.elements.map { |element| serialize_node(element) }
          }
        end

        # Cascade Expression: preserve condition/result pairs
        def serialize_cascade_expression(node)
          {
            cases: node.cases.map { |case_node| serialize_node(case_node) }
          }
        end

        # When Case Expression: individual case in cascade
        def serialize_when_case_expression(node)
          {
            condition: serialize_node(node.condition),
            result: serialize_node(node.result)
          }
        end

        private

        def serialize_type(type)
          case type
          when Symbol
            { type: "symbol", value: type.to_s }
          when Hash
            if type.key?(:array)
              { type: "array", element_type: serialize_type(type[:array]) }
            elsif type.key?(:hash)
              { type: "hash", key_type: serialize_type(type[:hash][0]), value_type: serialize_type(type[:hash][1]) }
            else
              { type: "hash", value: type }
            end
          when String, Integer, Float, TrueClass, FalseClass, NilClass
            { type: "literal", value: type }
          else
            { type: "unknown", value: type.to_s }
          end
        end

        def serialize_domain(domain)
          return nil unless domain

          case domain
          when Range
            { type: "range", min: domain.min, max: domain.max, exclude_end: domain.exclude_end? }
          when Array
            { type: "array", values: domain }
          else
            { type: "custom", value: domain.to_s }
          end
        end

        def serialize_node(node)
          type_name = NodeRegistry.type_name_for(node)

          base_data = {
            type: type_name,
            **send("serialize_#{type_name}", node)
          }

          add_location_if_present(base_data, node) if @include_locations
          base_data
        end

        def add_location_if_present(data, node)
          return unless node.respond_to?(:loc) && node.loc

          data[:location] = {
            line: node.loc.line,
            column: node.loc.column,
            file: node.loc.file
          }
        end
      end
    end
  end
end
