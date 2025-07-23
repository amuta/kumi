# frozen_string_literal: true

module Kumi
  module Analyzer
    module Passes
      class UnsatDetector < VisitorPass
        include Syntax

        COMPARATORS = %i[> < >= <= == !=].freeze
        Atom        = Kumi::StrictCycleChecker::Atom

        def run(errors)
          definitions = get_state(:definitions)
          each_decl do |decl|
            if decl.expression.is_a?(CascadeExpression)
              # Special handling for cascade expressions
              check_cascade_expression(decl, definitions, errors)
            else
              # Normal handling for non-cascade expressions
              atoms = gather_atoms(decl.expression, definitions, Set.new)
              next if atoms.empty?

              add_error(errors, decl.loc, "conjunction in `#{decl.name}` is logically impossible") if Kumi::StrictCycleChecker.unsat?(atoms)
            end
          end
        end

        private

        def gather_atoms(node, defs, visited, list = [])
          return list unless node

          if node.is_a?(CallExpression) && COMPARATORS.include?(node.fn_name)
            lhs, rhs = node.args
            list << Atom.new(node.fn_name, term(lhs), term(rhs))
          elsif node.is_a?(Binding)
            name = node.name
            unless visited.include?(name)
              visited << name
              gather_atoms(defs[name].expression, defs, visited, list) if defs.key?(name)
            end
          end

          node.children.each { |c| gather_atoms(c, defs, visited, list) } if node.respond_to?(:children)

          list
        end

        def check_cascade_expression(decl, definitions, errors)
          # Analyze each cascade branch condition independently
          # This is the correct behavior: each 'on' condition should be checked separately
          # since only ONE will be evaluated at runtime (they're mutually exclusive by design)

          decl.expression.cases.each_with_index do |when_case, _index|
            # Skip the base case (it's typically a literal true condition)
            next if when_case.condition.is_a?(Literal) && when_case.condition.value == true

            # Gather atoms from this individual condition only
            condition_atoms = gather_atoms(when_case.condition, definitions, Set.new, [])

            # Only flag if this individual condition is impossible
            if !condition_atoms.empty? && Kumi::StrictCycleChecker.unsat?(condition_atoms)
              add_error(errors, decl.loc, "conjunction in `#{decl.name}` is logically impossible")
            end
          end
        end

        def term(node)
          case node
          when FieldRef, Binding then node.name
          when Literal   then node.value
          else :unknown
          end
        end
      end
    end
  end
end
