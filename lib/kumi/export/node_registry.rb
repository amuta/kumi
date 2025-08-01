# frozen_string_literal: true

module Kumi
  module Export
    class NodeRegistry
      # Maps AST classes to JSON type names
      SERIALIZATION_MAP = {
        "Kumi::Syntax::Root" => "root",
        "Kumi::Syntax::InputDeclaration" => "field_declaration",
        "Kumi::Syntax::ValueDeclaration" => "attribute_declaration",
        "Kumi::Syntax::TraitDeclaration" => "trait_declaration",
        "Kumi::Syntax::CallExpression" => "call_expression",
        "Kumi::Syntax::ArrayExpression" => "list_expression",
        "Kumi::Syntax::HashExpression" => "hash_expression",
        "Kumi::Syntax::CascadeExpression" => "cascade_expression",
        "Kumi::Syntax::CaseExpression" => "when_case_expression",
        "Kumi::Syntax::Literal" => "literal",
        "Kumi::Syntax::InputReference" => "field_reference",
        "Kumi::Syntax::DeclarationReference" => "binding_reference"
      }.freeze

      # Maps JSON type names back to AST classes (using new canonical class names)
      DESERIALIZATION_MAP = {
        "root" => "Kumi::Syntax::Root",
        "field_declaration" => "Kumi::Syntax::InputDeclaration",
        "attribute_declaration" => "Kumi::Syntax::ValueDeclaration",
        "trait_declaration" => "Kumi::Syntax::TraitDeclaration",
        "call_expression" => "Kumi::Syntax::CallExpression",
        "list_expression" => "Kumi::Syntax::ArrayExpression",
        "hash_expression" => "Kumi::Syntax::HashExpression",
        "cascade_expression" => "Kumi::Syntax::CascadeExpression",
        "when_case_expression" => "Kumi::Syntax::CaseExpression",
        "literal" => "Kumi::Syntax::Literal",
        "field_reference" => "Kumi::Syntax::InputReference",
        "binding_reference" => "Kumi::Syntax::DeclarationReference"
      }.freeze

      def self.type_name_for(node)
        SERIALIZATION_MAP[node.class.name] or
          raise Kumi::Export::Errors::SerializationError, "Unknown node type: #{node.class.name}"
      end

      def self.class_for_type(type_name)
        class_name = DESERIALIZATION_MAP[type_name] or
          raise Kumi::Export::Errors::DeserializationError, "Unknown type name: #{type_name}"

        # Resolve the class from string name
        class_name.split("::").reduce(Object) { |const, name| const.const_get(name) }
      end
    end
  end
end
