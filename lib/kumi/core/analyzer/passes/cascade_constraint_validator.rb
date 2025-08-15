# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        # RESPONSIBILITY: Validate cascade_and usage constraints
        # DEPENDENCIES: :declarations (from earlier passes)
        # PRODUCES: None (validation only)
        # INTERFACE: new(schema, state).run(errors)
        #
        # This pass validates that cascade_and can only be used inside cascade expressions
        # (CaseExpression conditions). It runs after the toposorter but before cascade
        # desugaring, when the AST structure is stable but cascade_and hasn't been
        # transformed yet.
        class CascadeConstraintValidator < VisitorPass
          def run(errors)
            # Visit all declarations and validate cascade_and usage
            each_decl do |decl|
              validate_cascade_and_usage(decl, errors)
            end
            state
          end

          private

          def validate_cascade_and_usage(decl, errors)
            # Check the declaration expression for cascade_and calls
            case decl
            when Kumi::Syntax::TraitDeclaration
              # cascade_and should not be used in trait expressions
              check_for_forbidden_cascade_and(decl.expression, "trait expressions", errors)
            when Kumi::Syntax::ValueDeclaration
              # For value declarations, we need to check if it's a cascade expression
              case decl.expression
              when Kumi::Syntax::CascadeExpression
                # In cascade expressions, cascade_and is allowed only in case conditions
                validate_cascade_expression(decl.expression, errors)
              else
                # cascade_and should not be used in non-cascade value expressions
                check_for_forbidden_cascade_and(decl.expression, "non-cascade value expressions", errors)
              end
            end
          end

          def validate_cascade_expression(cascade_expr, errors)
            cascade_expr.cases.each do |case_expr|
              # cascade_and is allowed in case conditions
              # But should not appear in case results
              if case_expr.result
                check_for_forbidden_cascade_and(case_expr.result, "cascade result expressions", errors)
              end
            end
          end

          def check_for_forbidden_cascade_and(node, context, errors)
            return unless node

            visit(node) do |visited_node|
              if visited_node.is_a?(Kumi::Syntax::CallExpression) && visited_node.fn_name == :cascade_and
                report_error(
                  errors,
                  "cascade_and can only be used in cascade conditions (on clauses), not in #{context}. " \
                  "Use regular boolean operators (&, |) or separate trait definitions instead.",
                  location: visited_node.loc,
                  type: :semantic
                )
              end
            end
          end
        end
      end
    end
  end
end