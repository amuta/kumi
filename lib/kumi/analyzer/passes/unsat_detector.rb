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
            atoms = gather_atoms(decl.expression, definitions, Set.new)
            next if atoms.empty?

            add_error(errors, decl.loc, "conjunction in `#{decl.name}` is logically impossible") if Kumi::StrictCycleChecker.unsat?(atoms)
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
