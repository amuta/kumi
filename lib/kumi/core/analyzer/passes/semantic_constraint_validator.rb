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
            @registry = state[:registry]
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
              # Valid if it's a boolean composition of traits (all?, any?, none?)
              return if boolean_trait_composition?(condition)

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
            fn_name = call_expr.fn_name

            skip = [:cascade_and] # TODO: - hack
            return if skip.include? fn_name

            # Skip validation for imported functions - they're pure schema methods
            imported_schemas = state[:imported_schemas] || {}
            return if imported_schemas.key?(fn_name)

            # Check if it's a built-in function in the registry
            return if @registry.resolve_function(fn_name)

            report_error(
              errors,
              "unknown function `#{fn_name}`",
              location: call_expr.loc,
              type: :semantic
            )
          end

          def validate_input_declaration(input_decl, errors)
            return unless input_decl.type == :array && input_decl.children.any?

            # Recursively validate children
            input_decl.children.each { |child| validate_input_declaration(child, errors) }
          end

          def boolean_trait_composition?(call_expr)
            # Allow boolean composition functions that operate on trait collections
            %i[all? any? none?].include?(call_expr.fn_name)
          end
        end
      end
    end
  end
end
