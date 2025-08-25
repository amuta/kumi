# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        # RESPONSIBILITY: Detect unsatisfiable constraints and analyze cascade mutual exclusion
        # DEPENDENCIES: :declarations from NameIndexer, :input_metadata from InputCollector
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

            each_decl do |decl|
              if decl.expression.is_a?(CascadeExpression)
                check_cascade_expression(decl, definitions, errors)
              elsif decl.expression.is_a?(CallExpression) && decl.expression.fn_name == :or
                impossible = check_or_expression(decl.expression, definitions, errors)
                report_error(errors, "conjunction `#{decl.name}` is impossible", location: decl.loc) if impossible
              else
                atoms = gather_atoms(decl.expression, definitions, Set.new)
                next if atoms.empty?

                result = if definitions && !definitions.empty?
                           Kumi::Core::ConstraintRelationshipSolver.unsat?(atoms, definitions, input_meta: @input_meta)
                         else
                           Kumi::Core::AtomUnsatSolver.unsat?(atoms)
                         end
                impossible = result

                report_error(errors, "conjunction `#{decl.name}` is impossible", location: decl.loc) if impossible
              end
            end

            state
          end

          private

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

                list << if impossible_constraint?(lhs, rhs, current.fn_name)
                          Atom.new(:==, :__impossible__, true)
                        else
                          Atom.new(current.fn_name, term(lhs, defs), term(rhs, defs))
                        end
              elsif current.is_a?(CallExpression) && current.fn_name == :or
                next
              elsif current.is_a?(CallExpression) && current.fn_name == :cascade_and
                current.args.each { |arg| stack << arg }
              elsif current.is_a?(ArrayExpression)
                current.elements.each { |elem| stack << elem }
              elsif current.is_a?(DeclarationReference)
                name = current.name
                unless visited.include?(name)
                  visited << name
                  stack << defs[name].expression if defs.key?(name)
                end
              end

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
              if ENV["DEBUG_UNSAT"] || decl.loc&.to_s&.include?("hierarchical_broadcasting_spec.rb:257")
                puts "  Case #{index}: condition=#{when_case.condition.inspect}"
              end

              next if when_case.condition.is_a?(Literal) && when_case.condition.value == true

              next if when_case.condition.is_a?(CallExpression) && %i[any? none?].include?(when_case.condition.fn_name)

              if when_case.condition.is_a?(CallExpression) && when_case.condition.fn_name == :cascade_and && (when_case.condition.args.size == 1)
                next
              end

              condition_atoms = gather_atoms(when_case.condition, definitions, Set.new, [])

              if ENV["DEBUG_UNSAT"] || decl.loc&.to_s&.include?("hierarchical_broadcasting_spec.rb:257")
                puts "    Condition atoms: #{condition_atoms.map(&:inspect)}"
              end

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

              if when_case.condition.is_a?(CallExpression) && when_case.condition.fn_name == :cascade_and
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
              path_identifier = node.path.join(".").to_s
              path_identifier.to_sym
            when Literal
              node.value
            else
              :unknown
            end
          end

          def violates_domain?(value, domain)
            case domain
            when Range, Array
              !domain.include?(value)
            else
              false
            end
          end

          def impossible_constraint?(lhs, rhs, operator)
            # Case 1: InputReference compared against value outside its domain
            if lhs.is_a?(InputReference) && rhs.is_a?(Literal)
              return field_literal_impossible?(lhs, rhs, operator)
            elsif rhs.is_a?(InputReference) && lhs.is_a?(Literal)
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
              violates_domain?(literal_value, domain)
            when :!=
              false
            else
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
              evaluated_value != literal_value
            else
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
