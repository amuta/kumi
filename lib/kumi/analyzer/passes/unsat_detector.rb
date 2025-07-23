module Kumi
  module Analyzer
    module Passes
      class UnsatDetector < VisitorPass
        include Syntax

        COMPARATORS = %i[> < >= <= == !=].freeze
        Atom        = Kumi::StrictCycleChecker::Atom

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

              add_error(errors, decl.loc, "conjunction `#{decl.name}` is logically impossible") if Kumi::StrictCycleChecker.unsat?(atoms)
            end
          end
        end

        private

        def gather_atoms(node, defs, visited, list = [])
          return list unless node

          if node.is_a?(CallExpression) && COMPARATORS.include?(node.fn_name)
            lhs, rhs = node.args
            list << Atom.new(node.fn_name, term(lhs, defs), term(rhs, defs))
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

            # Skip single-trait 'on' branches: trait-level unsat detection covers these
            if when_case.condition.is_a?(CallExpression) && when_case.condition.fn_name == :all?
              list = when_case.condition.args.first
              next if list.is_a?(ListExpression) && list.elements.size < 2
            end
            # Gather atoms from this individual condition only
            condition_atoms = gather_atoms(when_case.condition, definitions, Set.new, [])

            # Only flag if this individual condition is impossible
            next unless !condition_atoms.empty? && Kumi::StrictCycleChecker.unsat?(condition_atoms)

            # For multi-trait on-clauses, report the trait names rather than the value name
            if when_case.condition.is_a?(CallExpression) && when_case.condition.fn_name == :all?
              list = when_case.condition.args.first
              if list.is_a?(ListExpression) && list.elements.all? { |a| a.is_a?(Binding) }
                traits = list.elements.map(&:name).join(" AND ")
                add_error(errors, decl.loc, "conjunction `#{traits}` is logically impossible")
                next
              end
            end
            add_error(errors, decl.loc, "conjunction `#{decl.name}` is logically impossible")
          end
        end

        def term(node, defs)
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
