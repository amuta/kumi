# frozen_string_literal: true

module Kumi
  module Analyzer
    module Passes
      class UnsatDetector < VisitorPass
        include Syntax

        COMPARATORS = %i[> < >= <= == !=].freeze
        Atom        = Kumi::AtomUnsatSolver::Atom

        def run(errors)
          definitions = get_state(:definitions)
          @evaluator = ConstantEvaluator.new(definitions)

          each_decl do |decl|
            if decl.expression.is_a?(CascadeExpression)
              # Special handling for cascade expressions
              check_cascade_expression(decl, definitions, errors)
            else
              # Normal handling for non-cascade expressions
              atoms = gather_atoms(decl.expression, definitions, Set.new)
              next if atoms.empty?

              report_error(errors, "conjunction `#{decl.name}` is impossible", location: decl.loc) if Kumi::AtomUnsatSolver.unsat?(atoms)
            end
          end
          state
        end

        private

        def gather_atoms(node, defs, visited, list = [])
          return list unless node

          # Use iterative approach with stack to avoid SystemStackError on deep graphs
          stack = [node]

          until stack.empty?
            current = stack.pop
            next unless current

            if current.is_a?(CallExpression) && COMPARATORS.include?(current.fn_name)
              lhs, rhs = current.args
              list << Atom.new(current.fn_name, term(lhs, defs), term(rhs, defs))
            elsif current.is_a?(Binding)
              name = current.name
              unless visited.include?(name)
                visited << name
                stack << defs[name].expression if defs.key?(name)
              end
            end

            # Add children to stack for processing
            # IMPORTANT: Skip CascadeExpression children to avoid false positives
            # Cascades are handled separately by check_cascade_expression() and are disjunctive,
            # but gather_atoms() treats all collected atoms as conjunctive
            if current.respond_to?(:children) && !current.is_a?(CascadeExpression)
              current.children.each { |child| stack << child }
            end
          end

          list
        end

        def check_cascade_expression(decl, definitions, errors)
          # Analyze each cascade branch condition independently
          # This is the correct behavior: each 'on' condition should be checked separately
          # since only ONE will be evaluated at runtime (they're mutually exclusive by design)

          decl.expression.cases.each_with_index do |when_case, _index|
            # Skip the base case (it's typically a literal true condition)
            next if when_case.condition.is_a?(Literal) && when_case.condition.value == true

            # Skip single-trait 'on' branches: trait-level unsat detection covers these
            if when_case.condition.is_a?(CallExpression) && when_case.condition.fn_name == :all?
              list = when_case.condition.args.first
              next if list.is_a?(ListExpression) && list.elements.size < 2
            end
            # Gather atoms from this individual condition only
            condition_atoms = gather_atoms(when_case.condition, definitions, Set.new, [])

            # Only flag if this individual condition is impossible
            next unless !condition_atoms.empty? && Kumi::AtomUnsatSolver.unsat?(condition_atoms)

            # For multi-trait on-clauses, report the trait names rather than the value name
            if when_case.condition.is_a?(CallExpression) && when_case.condition.fn_name == :all?
              list = when_case.condition.args.first
              if list.is_a?(ListExpression) && list.elements.all?(Binding)
                traits = list.elements.map(&:name).join(" AND ")
                report_error(errors, "conjunction `#{traits}` is impossible", location: decl.loc)
                next
              end
            end
            report_error(errors, "conjunction `#{decl.name}` is impossible", location: decl.loc)
          end
        end

        def term(node, _defs)
          case node
          when FieldRef, Binding
            val = @evaluator.evaluate(node)
            val == :unknown ? node.name : val
          when Literal
            node.value
          else
            :unknown
          end
        end
      end
    end
  end
end
