# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        # RESPONSIBILITY: Detect unsatisfiable constraints and analyze cascade mutual exclusion
        # DEPENDENCIES: :declarations from NameIndexer, :input_metadata from InputCollector
        # PRODUCES: :cascades - Hash of cascade mutual exclusion analysis results
        # INTERFACE: new(schema, state).run(errors)
        class UnsatDetector < VisitorPass
          include Syntax

          COMPARATORS = %i[> < >= <= == !=].freeze
          Atom        = Kumi::Core::AtomUnsatSolver::Atom

          def run(errors)
            definitions = get_state(:declarations)
            @input_meta = get_state(:input_metadata) || {}
            @definitions = definitions
            @evaluator = ConstantEvaluator.new(definitions)

            # First pass: analyze cascade conditions for mutual exclusion
            cascades = {}
            each_decl do |decl|
              cascades[decl.name] = analyze_cascade_mutual_exclusion(decl, definitions) if decl.expression.is_a?(CascadeExpression)

              # Store cascade metadata for later passes

              # Second pass: check for unsatisfiable constraints
              if decl.expression.is_a?(CascadeExpression)
                # Special handling for cascade expressions
                check_cascade_expression(decl, definitions, errors)
              elsif decl.expression.is_a?(CallExpression) && decl.expression.fn_name == :or
                # Check for OR expressions which need special disjunctive handling
                impossible = check_or_expression(decl.expression, definitions, errors)
                report_error(errors, "conjunction `#{decl.name}` is impossible", location: decl.loc) if impossible
              else
                # Normal handling for non-cascade expressions
                atoms = gather_atoms(decl.expression, definitions, Set.new)
                next if atoms.empty?

                # DEBUG: Add detailed logging for hierarchical broadcasting debugging
                if ENV["DEBUG_UNSAT"] || decl.loc&.to_s&.include?("hierarchical_broadcasting_spec.rb:257")
                  puts "DEBUG UNSAT: Checking declaration '#{decl.name}' at #{decl.loc}"
                  puts "  Expression: #{decl.expression.inspect}"
                  puts "  Gathered atoms: #{atoms.map(&:inspect)}"
                  puts "  Input meta: #{@input_meta.keys.inspect}" if @input_meta
                end

                # Use enhanced solver that can detect cross-variable mathematical constraints
                if definitions && !definitions.empty?
                  result = Kumi::Core::ConstraintRelationshipSolver.unsat?(atoms, definitions, input_meta: @input_meta)
                  if ENV["DEBUG_UNSAT"] || decl.loc&.to_s&.include?("hierarchical_broadcasting_spec.rb:257")
                    puts "  Enhanced solver result: #{result}"
                  end
                else
                  result = Kumi::Core::AtomUnsatSolver.unsat?(atoms)
                  if ENV["DEBUG_UNSAT"] || decl.loc&.to_s&.include?("hierarchical_broadcasting_spec.rb:257")
                    puts "  Basic solver result: #{result}"
                  end
                end
                impossible = result

                if impossible && (ENV["DEBUG_UNSAT"] || decl.loc&.to_s&.include?("hierarchical_broadcasting_spec.rb:257"))
                  puts "  -> FLAGGING AS IMPOSSIBLE: #{decl.name}"
                end

                report_error(errors, "conjunction `#{decl.name}` is impossible", location: decl.loc) if impossible
              end
            end
            state.with(:cascades, cascades)
          end

          private

          def analyze_cascade_mutual_exclusion(decl, definitions)
            conditions = []
            condition_traits = []

            # Extract all cascade conditions (except base case)
            decl.expression.cases[0...-1].each do |when_case|
              next unless when_case.condition

              next unless when_case.condition.fn_name == :cascade_and

              when_case.condition.args.each do |arg|
                if arg.is_a?(ArrayExpression)
                  # Handle array elements (for array broadcasting)
                  arg.elements.each do |element|
                    next unless element.is_a?(DeclarationReference)

                    trait_name = element.name
                    trait = definitions[trait_name]
                    if trait
                      conditions << trait.expression
                      condition_traits << trait_name
                    end
                  end
                elsif arg.is_a?(DeclarationReference)
                  # Handle direct trait references (simple case)
                  trait_name = arg.name
                  trait = definitions[trait_name]
                  if trait
                    conditions << trait.expression
                    condition_traits << trait_name
                  end
                end
              end
              # end
            end

            # Check mutual exclusion for all pairs
            total_pairs = conditions.size * (conditions.size - 1) / 2
            exclusive_pairs = 0

            if conditions.size >= 2
              conditions.combination(2).each do |cond1, cond2|
                exclusive_pairs += 1 if conditions_mutually_exclusive?(cond1, cond2)
              end
            end

            all_mutually_exclusive = total_pairs.positive? && (exclusive_pairs == total_pairs)

            {
              condition_traits: condition_traits,
              condition_count: conditions.size,
              all_mutually_exclusive: all_mutually_exclusive,
              exclusive_pairs: exclusive_pairs,
              total_pairs: total_pairs
            }
          end

          def conditions_mutually_exclusive?(cond1, cond2)
            if cond1.is_a?(CallExpression) && cond1.fn_name == :== &&
               cond2.is_a?(CallExpression) && cond2.fn_name == :==

              c1_field, c1_value = cond1.args
              c2_field, c2_value = cond2.args

              # Same field, different values = mutually exclusive
              return true if same_field?(c1_field, c2_field) && different_values?(c1_value, c2_value)
            end

            false
          end

          def same_field?(field1, field2)
            return false unless field1.is_a?(InputReference) && field2.is_a?(InputReference)

            field1.name == field2.name
          end

          def different_values?(val1, val2)
            return false unless val1.is_a?(Literal) && val2.is_a?(Literal)

            val1.value != val2.value
          end

          def check_or_expression(or_expr, definitions, _errors)
            # For OR expressions: A | B is impossible only if BOTH A AND B are impossible
            # If either side is satisfiable, the OR is satisfiable
            left_side, right_side = or_expr.args

            # Check if left side is impossible
            left_atoms = gather_atoms(left_side, definitions, Set.new)
            left_impossible = if left_atoms.empty?
                                false
                              elsif definitions && !definitions.empty?
                                Kumi::Core::ConstraintRelationshipSolver.unsat?(left_atoms, definitions, input_meta: @input_meta)
                              else
                                Kumi::Core::AtomUnsatSolver.unsat?(left_atoms)
                              end

            # Check if right side is impossible
            right_atoms = gather_atoms(right_side, definitions, Set.new)
            right_impossible = if right_atoms.empty?
                                 false
                               elsif definitions && !definitions.empty?
                                 Kumi::Core::ConstraintRelationshipSolver.unsat?(right_atoms, definitions, input_meta: @input_meta)
                               else
                                 Kumi::Core::AtomUnsatSolver.unsat?(right_atoms)
                               end

            # OR is impossible only if BOTH sides are impossible
            left_impossible && right_impossible
          end

          def gather_atoms(node, defs, visited, list = [])
            return list unless node

            # Use iterative approach with stack to avoid SystemStackError on deep graphs
            stack = [node]

            until stack.empty?
              current = stack.pop
              next unless current

              if current.is_a?(CallExpression) && COMPARATORS.include?(current.fn_name)
                lhs, rhs = current.args

                # Check for domain constraint violations before creating atom
                list << if impossible_constraint?(lhs, rhs, current.fn_name)
                          # Create a special impossible atom that will always trigger unsat
                          Atom.new(:==, :__impossible__, true)
                        else
                          Atom.new(current.fn_name, term(lhs, defs), term(rhs, defs))
                        end
              elsif current.is_a?(CallExpression) && current.fn_name == :or
                # Special handling for OR expressions - they are disjunctive, not conjunctive
                # We should NOT add OR children to the stack as they would be treated as AND
                # OR expressions need separate analysis in the main run() method
                next
              elsif current.is_a?(CallExpression) && current.fn_name == :cascade_and
                # cascade_and takes individual arguments (not wrapped in array)
                current.args.each { |arg| stack << arg }
              elsif current.is_a?(ArrayExpression)
                # For ArrayExpression, add all elements to the stack
                current.elements.each { |elem| stack << elem }
              elsif current.is_a?(DeclarationReference)
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
              current.children.each { |child| stack << child } if current.respond_to?(:children) && !current.is_a?(CascadeExpression)
            end

            list
          end

          def check_cascade_expression(decl, definitions, errors)
            # Analyze each cascade branch condition independently
            # This is the correct behavior: each 'on' condition should be checked separately
            # since only ONE will be evaluated at runtime (they're mutually exclusive by design)

            # DEBUG: Add detailed logging for hierarchical broadcasting debugging
            if ENV["DEBUG_UNSAT"] || decl.loc&.to_s&.include?("hierarchical_broadcasting_spec.rb:257")
              puts "DEBUG UNSAT CASCADE: Checking cascade '#{decl.name}' at #{decl.loc}"
              puts "  Total cases: #{decl.expression.cases.length}"
            end

            decl.expression.cases.each_with_index do |when_case, index|
              # DEBUG: Log each case
              if ENV["DEBUG_UNSAT"] || decl.loc&.to_s&.include?("hierarchical_broadcasting_spec.rb:257")
                puts "  Case #{index}: condition=#{when_case.condition.inspect}"
              end

              # Skip the base case (it's typically a literal true condition)
              next if when_case.condition.is_a?(Literal) && when_case.condition.value == true

              # Skip non-conjunctive conditions (any?, none?) as they are disjunctive
              next if when_case.condition.is_a?(CallExpression) && %i[any? none?].include?(when_case.condition.fn_name)

              # Skip single-trait 'on' branches: trait-level unsat detection covers these
              if when_case.condition.is_a?(CallExpression) && when_case.condition.fn_name == :cascade_and && (when_case.condition.args.size == 1)
                # cascade_and uses individual arguments - skip if only one trait
                next
              end

              # Gather atoms from this individual condition only
              condition_atoms = gather_atoms(when_case.condition, definitions, Set.new, [])

              # DEBUG: Add detailed logging for hierarchical broadcasting debugging
              if ENV["DEBUG_UNSAT"] || decl.loc&.to_s&.include?("hierarchical_broadcasting_spec.rb:257")
                puts "    Condition atoms: #{condition_atoms.map(&:inspect)}"
              end

              # Use enhanced solver for cascade conditions too
              if definitions && !definitions.empty?
                result = Kumi::Core::ConstraintRelationshipSolver.unsat?(condition_atoms, definitions, input_meta: @input_meta)
                if ENV["DEBUG_UNSAT"] || decl.loc&.to_s&.include?("hierarchical_broadcasting_spec.rb:257")
                  puts "    Enhanced solver result: #{result}"
                end
              else
                result = Kumi::Core::AtomUnsatSolver.unsat?(condition_atoms)
                if ENV["DEBUG_UNSAT"] || decl.loc&.to_s&.include?("hierarchical_broadcasting_spec.rb:257")
                  puts "    Basic solver result: #{result}"
                end
              end
              impossible = result
              next unless !condition_atoms.empty? && impossible

              # For multi-trait on-clauses, report the trait names rather than the value name
              if when_case.condition.is_a?(CallExpression) && when_case.condition.fn_name == :cascade_and
                # cascade_and uses individual arguments
                trait_bindings = when_case.condition.args

                if trait_bindings.all?(DeclarationReference)
                  traits = trait_bindings.map(&:name).join(" AND ")
                  if ENV["DEBUG_UNSAT"] || decl.loc&.to_s&.include?("hierarchical_broadcasting_spec.rb:257")
                    puts "    -> FLAGGING AS IMPOSSIBLE CASCADE CONDITION: #{traits}"
                  end
                  report_error(errors, "conjunction `#{traits}` is impossible", location: decl.loc)
                  next
                end
              end
              if ENV["DEBUG_UNSAT"] || decl.loc&.to_s&.include?("hierarchical_broadcasting_spec.rb:257")
                puts "    -> FLAGGING AS IMPOSSIBLE CASCADE: #{decl.name}"
              end
              report_error(errors, "conjunction `#{decl.name}` is impossible", location: decl.loc)
            end
          end

          def term(node, _defs)
            case node
            when InputReference, DeclarationReference
              val = @evaluator.evaluate(node)
              val == :unknown ? node.name : val
            when InputElementReference
              # For hierarchical paths like input.companies.regions.offices.teams.department,
              # create a unique identifier that represents the specific path
              # This prevents false positives where different paths are treated as the same :unknown
              path_identifier = node.path.join(".").to_s
              path_identifier.to_sym
            when Literal
              node.value
            else
              :unknown
            end
          end

          def check_domain_constraints(node, definitions, errors)
            case node
            when InputReference
              # Check if InputReference points to a field with domain constraints
              field_meta = @input_meta[node.name]
              nil unless field_meta&.dig(:domain)

              # For InputReference, the constraint comes from trait conditions
              # We don't flag here since the InputReference itself is valid
            when DeclarationReference
              # Check if this binding evaluates to a value that violates domain constraints
              definition = definitions[node.name]
              return unless definition

              if definition.expression.is_a?(Literal)
                literal_value = definition.expression.value
                check_value_against_domains(node.name, literal_value, errors, definition.loc)
              end
            end
          end

          def check_value_against_domains(_var_name, value, _errors, _location)
            # Check if this value violates any input domain constraints
            @input_meta.each_value do |field_meta|
              domain = field_meta[:domain]
              next unless domain

              if violates_domain?(value, domain)
                # This indicates a constraint that can never be satisfied
                # Rather than flagging the cascade, flag the impossible condition
                return true
              end
            end
            false
          end

          def violates_domain?(value, domain)
            case domain
            when Range
              !domain.include?(value)
            when Array
              !domain.include?(value)
            when Proc
              # For Proc domains, we can't statically analyze
              false
            else
              false
            end
          end

          def impossible_constraint?(lhs, rhs, operator)
            # Case 1: InputReference compared against value outside its domain
            if lhs.is_a?(InputReference) && rhs.is_a?(Literal)
              return field_literal_impossible?(lhs, rhs, operator)
            elsif rhs.is_a?(InputReference) && lhs.is_a?(Literal)
              # Reverse case: literal compared to field
              return field_literal_impossible?(rhs, lhs, flip_operator(operator))
            end

            # Case 2: DeclarationReference that evaluates to literal compared against impossible value
            if lhs.is_a?(DeclarationReference) && rhs.is_a?(Literal)
              return binding_literal_impossible?(lhs, rhs, operator)
            elsif rhs.is_a?(DeclarationReference) && lhs.is_a?(Literal)
              return binding_literal_impossible?(rhs, lhs, flip_operator(operator))
            end

            false
          end

          def field_literal_impossible?(field_ref, literal, operator)
            field_meta = @input_meta[field_ref.name]
            return false unless field_meta&.dig(:domain)

            domain = field_meta[:domain]
            literal_value = literal.value

            case operator
            when :==
              # field == value where value is not in domain
              violates_domain?(literal_value, domain)
            when :!=
              # field != value where value is not in domain is always true (not impossible)
              false
            else
              # For other operators, we'd need more sophisticated analysis
              false
            end
          end

          def binding_literal_impossible?(binding, literal, operator)
            # Check if binding evaluates to a literal that conflicts with the comparison
            evaluated_value = @evaluator.evaluate(binding)
            return false if evaluated_value == :unknown

            literal_value = literal.value

            case operator
            when :==
              # binding == value where binding evaluates to different value
              evaluated_value != literal_value
            else
              # For other operators, we could add more sophisticated checking
              false
            end
          end

          def flip_operator(operator)
            case operator
            when :> then :<
            when :>= then :<=
            when :< then :>
            when :<= then :>=
            when :== then :==
            when :!= then :!=
            else operator
            end
          end
        end
      end
    end
  end
end
