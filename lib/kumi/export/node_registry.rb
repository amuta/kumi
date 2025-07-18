# frozen_string_literal: true

module Kumi
  module Export
    class NodeRegistry
      # Maps AST classes to JSON type names
      SERIALIZATION_MAP = {
        "Kumi::Syntax::Root" => "root",
        "Kumi::Syntax::Declarations::FieldDecl" => "field_declaration",
        "Kumi::Syntax::Declarations::Attribute" => "attribute_declaration",
        "Kumi::Syntax::Declarations::Trait" => "trait_declaration",
        "Kumi::Syntax::Expressions::CallExpression" => "call_expression",
        "Kumi::Syntax::TerminalExpressions::Literal" => "literal",
        "Kumi::Syntax::TerminalExpressions::FieldRef" => "field_reference",
        "Kumi::Syntax::TerminalExpressions::Binding" => "binding_reference",
        "Kumi::Syntax::Expressions::ListExpression" => "list_expression",
        "Kumi::Syntax::Expressions::CascadeExpression" => "cascade_expression",
        "Kumi::Syntax::Expressions::WhenCaseExpression" => "when_case_expression"
      }.freeze

      # Maps JSON type names back to AST classes
      DESERIALIZATION_MAP = SERIALIZATION_MAP.invert.freeze

      def self.type_name_for(node)
        SERIALIZATION_MAP[node.class.name] or
          raise Kumi::Export::SerializationError, "Unknown node type: #{node.class.name}"
      end

      def self.class_for_type(type_name)
        class_name = DESERIALIZATION_MAP[type_name] or
          raise Kumi::Export::DeserializationError, "Unknown type name: #{type_name}"

        # Resolve the class from string name
        class_name.split("::").reduce(Object) { |const, name| const.const_get(name) }
      end
    end
  end
end
