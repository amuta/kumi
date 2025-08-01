# frozen_string_literal: true

module Kumi
  module Core
    module Export
      class NodeRegistry
        # Maps AST classes to JSON type names
        SERIALIZATION_MAP = {
          "Kumi::Core::Syntax::Root" => "root",
          "Kumi::Core::Syntax::InputDeclaration" => "field_declaration",
          "Kumi::Core::Syntax::ValueDeclaration" => "attribute_declaration",
          "Kumi::Core::Syntax::TraitDeclaration" => "trait_declaration",
          "Kumi::Core::Syntax::CallExpression" => "call_expression",
          "Kumi::Core::Syntax::ArrayExpression" => "list_expression",
          "Kumi::Core::Syntax::HashExpression" => "hash_expression",
          "Kumi::Core::Syntax::CascadeExpression" => "cascade_expression",
          "Kumi::Core::Syntax::CaseExpression" => "when_case_expression",
          "Kumi::Core::Syntax::Literal" => "literal",
          "Kumi::Core::Syntax::InputReference" => "field_reference",
          "Kumi::Core::Syntax::DeclarationReference" => "binding_reference"
        }.freeze

        # Maps JSON type names back to AST classes (using new canonical class names)
        DESERIALIZATION_MAP = {
          "root" => "Kumi::Core::Syntax::Root",
          "field_declaration" => "Kumi::Core::Syntax::InputDeclaration",
          "attribute_declaration" => "Kumi::Core::Syntax::ValueDeclaration",
          "trait_declaration" => "Kumi::Core::Syntax::TraitDeclaration",
          "call_expression" => "Kumi::Core::Syntax::CallExpression",
          "list_expression" => "Kumi::Core::Syntax::ArrayExpression",
          "hash_expression" => "Kumi::Core::Syntax::HashExpression",
          "cascade_expression" => "Kumi::Core::Syntax::CascadeExpression",
          "when_case_expression" => "Kumi::Core::Syntax::CaseExpression",
          "literal" => "Kumi::Core::Syntax::Literal",
          "field_reference" => "Kumi::Core::Syntax::InputReference",
          "binding_reference" => "Kumi::Core::Syntax::DeclarationReference"
        }.freeze

        def self.type_name_for(node)
          SERIALIZATION_MAP[node.class.name] or
            raise Kumi::Core::Export::Errors::SerializationError, "Unknown node type: #{node.class.name}"
        end

        def self.class_for_type(type_name)
          class_name = DESERIALIZATION_MAP[type_name] or
            raise Kumi::Core::Export::Errors::DeserializationError, "Unknown type name: #{type_name}"

          # Resolve the class from string name
          class_name.split("::").reduce(Object) { |const, name| const.const_get(name) }
        end
      end
    end
  end
end
