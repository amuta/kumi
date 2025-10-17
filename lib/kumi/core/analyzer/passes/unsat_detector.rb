# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        # RESPONSIBILITY: Detect unsatisfiable constraints using formal constraint semantics
        # DEPENDENCIES: :declarations, :input_metadata, :registry, SNAST representation
        # INTERFACE: new(schema, state).run(errors)
        #
        # Detects when constraints are clearly unsatisfiable using constraint propagation:
        # 1. Same variable with contradicting equality values (v == 5 AND v == 10)
        # 2. Values violating input domain constraints
        # 3. Constraints derived through arithmetic operations that violate domains
        class UnsatDetector < VisitorPass
          include Syntax

          COMPARATORS = %i[> < >= <= == !=].freeze

          def run(errors)
            definitions = get_state(:declarations)
            input_meta = get_state(:input_metadata) || {}
            registry = get_state(:registry)

            @propagator = FormalConstraintPropagator.new(schema, state)

            each_decl do |decl|
              # Only check trait declarations for obvious contradictions
              next unless decl.is_a?(TraitDeclaration)

              atoms = extract_equality_atoms(decl.expression, definitions)
              next if atoms.empty?

              # Check for formal, obvious contradictions
              if contradicting_equalities?(atoms) || domain_violations?(atoms, input_meta) ||
                 propagated_violations?(atoms, definitions, input_meta, registry)
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
              return true unless domain.include?(value)
            end

            false
          end

          # FORMAL RULE 3: Propagated constraint violations
          # Propagate constraints through operations to derive hidden impossibilities
          def propagated_violations?(atoms, definitions, input_meta, registry)
            propagated = propagate_constraints(atoms, definitions, registry)
            return false if propagated.empty?

            propagated_domain_violations?(propagated, input_meta)
          end

          # Propagate constraints through operation definitions
          def propagate_constraints(atoms, definitions, registry)
            propagated = []

            atoms.each do |atom|
              variable = atom[:lhs]
              value = atom[:rhs]

              next unless value.is_a?(Numeric)

              definition = definitions[variable]
              next unless definition&.is_a?(ValueDeclaration)

              propagated.concat(propagate_through_operation(definition, variable, value, registry, definitions))
            end

            propagated
          end

          # Propagate a single constraint through an operation
          def propagate_through_operation(decl, variable, value, registry, definitions)
            expr = decl.expression
            return [] unless expr.is_a?(CallExpression)

            fn_id = registry.resolve_function(expr.fn_name)
            return [] unless fn_id

            operation = registry.function(fn_id)
            return [] unless operation

            operand_map = build_operand_map(expr, definitions)
            constraint = { variable: variable, op: :==, value: value }

            propagated_constraint = @propagator.propagate_reverse_through_operation(
              constraint,
              operation,
              operand_map
            )

            propagated_constraint ? [propagated_constraint] : []
          end

          # Build operand map for an operation expression
          def build_operand_map(expr, definitions)
            args = expr.args
            map = {}

            if args.size >= 2
              left_val = extract_operand_value(args[0], definitions)
              right_val = extract_operand_value(args[1], definitions)

              map[:left_operand] = left_val
              map[:right_operand] = right_val
            end

            map
          end

          # Extract operand value (symbol for variable, numeric for constant)
          def extract_operand_value(node, _definitions)
            case node
            when Literal
              node.value
            when DeclarationReference
              node.name
            when InputReference
              node.name
            end
          end

          # Check if propagated constraints violate input domain
          def propagated_domain_violations?(propagated, input_meta)
            propagated.each do |constraint|
              next unless constraint[:op] == :==

              variable = constraint[:variable]
              value = constraint[:value]

              next unless value.is_a?(Numeric)

              metadata = input_meta[variable]
              next unless metadata&.dig(:domain)

              domain = metadata[:domain]
              return true unless domain.include?(value)
            end

            false
          end
        end
      end
    end
  end
end
