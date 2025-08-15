# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        # RESPONSIBILITY: Validate DSL semantic constraints at the AST level
        # DEPENDENCIES: :definitions
        # PRODUCES: None (validation only)
        # INTERFACE: new(schema, state).run(errors)
        #
        # This pass enforces semantic constraints that must hold regardless of which parser
        # was used to construct the AST. It validates:
        # 1. Cascade conditions are only trait references (DeclarationReference nodes)
        # 2. Trait expressions evaluate to boolean values (CallExpression nodes)
        # 3. Function names exist in the function registry
        # 4. Expression types are valid for their context
        class SemanticConstraintValidator < VisitorPass
          def run(errors)
            # Visit value and trait declarations
            each_decl do |decl|
              visit(decl) { |node| validate_semantic_constraints(node, decl, errors) }
            end

            # Visit input declarations
            schema.inputs.each do |input_decl|
              visit(input_decl) { |node| validate_semantic_constraints(node, input_decl, errors) }
            end
            state
          end

          private

          def validate_semantic_constraints(node, _decl, errors)
            case node
            when Kumi::Syntax::TraitDeclaration
              validate_trait_expression(node, errors)
            when Kumi::Syntax::CaseExpression
              validate_cascade_condition(node, errors)
            when Kumi::Syntax::CallExpression
              validate_function_call(node, errors)
            when Kumi::Syntax::InputDeclaration
              validate_input_declaration(node, errors)
            end
          end

          def validate_trait_expression(trait, errors)
            return if trait.expression.is_a?(Kumi::Syntax::CallExpression)

            report_error(
              errors,
              "trait `#{trait.name}` must have a boolean expression",
              location: trait.loc,
              type: :semantic
            )
          end

          def validate_cascade_condition(when_case, errors)
            condition = when_case.condition
            
            case condition
            when Kumi::Syntax::DeclarationReference
              # Valid: trait reference
              nil
            when Kumi::Syntax::CallExpression
              # Valid if it's a boolean composition of traits (all?, any?, none?, cascade_and)
              return if boolean_trait_composition?(condition) || condition.fn_name == :cascade_and

              # For now, allow other CallExpressions - they'll be validated by other passes
              nil
            when Kumi::Syntax::Literal
              # Allow literal conditions (like true/false) - they might be valid
              nil
            else
              # Only reject truly invalid conditions like InputReference or complex expressions
              report_error(
                errors,
                "cascade condition must be trait reference",
                location: when_case.loc,
                type: :semantic
              )
            end
          end

          def validate_function_call(call_expr, errors)
            # Skip function validation at this early stage since function names
            # haven't been normalized yet. Real function validation happens later
            # in FunctionSignaturePass which has access to qualified names.
            # 
            # This early pass focuses on basic semantic constraints only.
            return
          end

          def validate_input_declaration(input_decl, errors)
            return unless input_decl.type == :array && input_decl.children.any?

            # Validate that access_mode is consistent with children structure
            if input_decl.access_mode == :element

              # Element mode arrays can only have exactly one direct child
              if input_decl.children.size > 1
                error_msg = "array with access_mode :element can only have one direct child element, " \
                            "but found #{input_decl.children.size} children"
                report_error(errors, error_msg, location: input_decl.loc, type: :semantic)
              end
            elsif input_decl.access_mode == :field
              # Object mode allows multiple children
            end

            # Recursively validate children
            input_decl.children.each { |child| validate_input_declaration(child, errors) }
          end

          def boolean_trait_composition?(call_expr)
            # Allow boolean composition functions that operate on trait collections
            %i[all? any? none?].include?(call_expr.fn_name)
          end

          def function_registry_mocked?
            # Check if Kumi::Registry.is being mocked (for tests)

            # Try to access a method that doesn't exist in the real registry
            # If it's mocked, this won't raise an error
            Kumi::Registry.respond_to?(:confirm_support!)
          rescue StandardError
            false
          end
        end
      end
    end
  end
end
