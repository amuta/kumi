# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        # RESPONSIBILITY: Detect unsatisfiable constraints using formal constraint semantics
        # DEPENDENCIES: :declarations from NameIndexer, :input_metadata from InputCollector, :registry
        # INTERFACE: new(schema, state).run(errors)
        #
        # Uses ONLY formal, obvious detection - no hardcoded operation logic.
        # Detects when constraints are clearly unsatisfiable:
        # 1. Same variable with contradicting equality values (v == 5 AND v == 10)
        # 2. Values violating input domain constraints
        class UnsatDetector < VisitorPass
          include Syntax

          COMPARATORS = %i[> < >= <= == !=].freeze

          def run(errors)
            definitions = get_state(:declarations)
            input_meta = get_state(:input_metadata) || {}

            each_decl do |decl|
              # Only check trait declarations for obvious contradictions
              next unless decl.is_a?(TraitDeclaration)

              atoms = extract_equality_atoms(decl.expression, definitions)
              next if atoms.empty?

              # Check for formal, obvious contradictions
              if contradicting_equalities?(atoms) || domain_violations?(atoms, input_meta)
                report_error(
                  errors,
                  "conjunction `#{decl.name}` is impossible",
                  location: decl.loc
                )
              end
            end

            state
          end

          private

          # Extract equality constraints from expression
          # Returns array of {op: :==, lhs: symbol, rhs: value} hashes
          def extract_equality_atoms(expr, definitions)
            atoms = []
            stack = [expr]
            visited = Set.new

            until stack.empty?
              current = stack.pop
              next unless current

              case current
              when CallExpression
                if current.fn_name == :==
                  lhs, rhs = current.args
                  lhs_val = extract_term(lhs, definitions)
                  rhs_val = extract_term(rhs, definitions)
                  atoms << { op: :==, lhs: lhs_val, rhs: rhs_val } if lhs_val && rhs_val
                elsif current.fn_name == :and
                  current.args.each { |arg| stack << arg }
                end
              when DeclarationReference
                unless visited.include?(current.name)
                  visited << current.name
                  stack << definitions[current.name]&.expression
                end
              end
            end

            atoms
          end

          # Extract value from AST node
          # Returns symbol for variables, literal values for constants
          def extract_term(node, definitions)
            case node
            when Literal
              node.value
            when DeclarationReference
              val = evaluate_to_literal(node, definitions)
              val == :unknown ? node.name : val
            when InputReference
              node.name
            else
              nil
            end
          end

          # Try to evaluate a declaration to a literal constant
          def evaluate_to_literal(decl_ref, definitions)
            definition = definitions[decl_ref.name]
            return :unknown unless definition&.expression.is_a?(Literal)

            definition.expression.value
          end

          # FORMAL RULE 1: Contradicting equalities
          # IF: same_variable == value1 AND same_variable == value2 AND value1 != value2
          # THEN: unsatisfiable
          def contradicting_equalities?(atoms)
            by_lhs = atoms.group_by { |a| a[:lhs] }

            by_lhs.each do |_lhs, constraints|
              rhs_values = constraints.map { |c| c[:rhs] }.uniq
              return true if rhs_values.size > 1
            end

            false
          end

          # FORMAL RULE 2: Domain violations
          # IF: variable is input field AND domain constraint exists AND value outside domain
          # THEN: unsatisfiable
          def domain_violations?(atoms, input_meta)
            atoms.each do |atom|
              variable = atom[:lhs]
              value = atom[:rhs]

              next unless value.is_a?(Numeric)

              metadata = input_meta[variable]
              next unless metadata&.dig(:domain)

              domain = metadata[:domain]
              return true if !domain.include?(value)
            end

            false
          end
        end
      end
    end
  end
end
