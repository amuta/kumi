# frozen_string_literal: true

require_relative "../../constraint_relationship_solver"

module Kumi
  module Analyzer
    module Passes
      class UnsatDetector < VisitorPass
        include Syntax

        COMPARATORS = %i[> < >= <= == !=].freeze
        Atom        = Kumi::AtomUnsatSolver::Atom

        def run(errors)
          definitions = get_state(:definitions)
          @input_meta = get_state(:input_meta) || {}
          @evaluator = ConstantEvaluator.new(definitions)

          each_decl do |decl|
            if decl.expression.is_a?(CascadeExpression)
              # Special handling for cascade expressions
              check_cascade_expression(decl, definitions, errors)
            else
              # Normal handling for non-cascade expressions
              atoms = gather_atoms(decl.expression, definitions, Set.new)
              next if atoms.empty?

              # Use enhanced solver that can detect cross-variable mathematical constraints
              impossible = if definitions && !definitions.empty?
                             Kumi::ConstraintRelationshipSolver.unsat?(atoms, definitions, input_meta: @input_meta)
                           else
                             Kumi::AtomUnsatSolver.unsat?(atoms)
                           end
              
              report_error(errors, "conjunction `#{decl.name}` is impossible", location: decl.loc) if impossible
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
              
              # Check for domain constraint violations before creating atom
              if impossible_constraint?(lhs, rhs, current.fn_name)
                # Create a special impossible atom that will always trigger unsat
                list << Atom.new(:==, :__impossible__, true)
              else
                list << Atom.new(current.fn_name, term(lhs, defs), term(rhs, defs))
              end
            elsif current.is_a?(CallExpression) && current.fn_name == :all?
              # For all? function, add all trait arguments to the stack
              current.args.each { |arg| stack << arg }
            elsif current.is_a?(ListExpression)
              # For ListExpression, add all elements to the stack
              current.elements.each { |elem| stack << elem }
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

            # Skip non-conjunctive conditions (any?, none?) as they are disjunctive
            if when_case.condition.is_a?(CallExpression) && [:any?, :none?].include?(when_case.condition.fn_name)
              next
            end
            
            # Skip single-trait 'on' branches: trait-level unsat detection covers these
            if when_case.condition.is_a?(CallExpression) && when_case.condition.fn_name == :all?
              # Handle both ListExpression (old format) and multiple args (new format)
              if when_case.condition.args.size == 1 && when_case.condition.args.first.is_a?(ListExpression)
                list = when_case.condition.args.first
                next if list.elements.size == 1
              else
                # Multiple args format
                next if when_case.condition.args.size == 1
              end
            end
            # Gather atoms from this individual condition only
            condition_atoms = gather_atoms(when_case.condition, definitions, Set.new, [])
            # DEBUG
            # if when_case.condition.is_a?(CallExpression) && [:all?, :any?, :none?].include?(when_case.condition.fn_name)
            #   puts "DEBUG: Processing #{when_case.condition.fn_name} condition"
            #   puts "  Args: #{when_case.condition.args.inspect}"
            #   puts "  Atoms found: #{condition_atoms.inspect}"
            # end

            # Only flag if this individual condition is impossible
            # if !condition_atoms.empty?
            #   is_unsat = Kumi::AtomUnsatSolver.unsat?(condition_atoms)
            #   puts "  Is unsat? #{is_unsat}"
            # end
            # Use enhanced solver for cascade conditions too
            impossible = if definitions && !definitions.empty?
                           Kumi::ConstraintRelationshipSolver.unsat?(condition_atoms, definitions, input_meta: @input_meta)
                         else
                           Kumi::AtomUnsatSolver.unsat?(condition_atoms)
                         end
            next unless !condition_atoms.empty? && impossible

            # For multi-trait on-clauses, report the trait names rather than the value name
            if when_case.condition.is_a?(CallExpression) && when_case.condition.fn_name == :all?
              # Handle both ListExpression (old format) and multiple args (new format)
              trait_bindings = if when_case.condition.args.size == 1 && when_case.condition.args.first.is_a?(ListExpression)
                                 when_case.condition.args.first.elements
                               else
                                 when_case.condition.args
                               end
              
              if trait_bindings.all? { |e| e.is_a?(Binding) }
                traits = trait_bindings.map(&:name).join(" AND ")
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

        def check_domain_constraints(node, definitions, errors)
          case node
          when FieldRef
            # Check if FieldRef points to a field with domain constraints
            field_meta = @input_meta[node.name]
            return unless field_meta&.dig(:domain)

            # For FieldRef, the constraint comes from trait conditions
            # We don't flag here since the FieldRef itself is valid
          when Binding
            # Check if this binding evaluates to a value that violates domain constraints
            definition = definitions[node.name]
            return unless definition

            if definition.expression.is_a?(Literal)
              literal_value = definition.expression.value
              check_value_against_domains(node.name, literal_value, errors, definition.loc)
            end
          end
        end

        def check_value_against_domains(var_name, value, errors, location)
          # Check if this value violates any input domain constraints
          @input_meta.each do |field_name, field_meta|
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
          # Case 1: FieldRef compared against value outside its domain
          if lhs.is_a?(FieldRef) && rhs.is_a?(Literal)
            return field_literal_impossible?(lhs, rhs, operator)
          elsif rhs.is_a?(FieldRef) && lhs.is_a?(Literal)
            # Reverse case: literal compared to field
            return field_literal_impossible?(rhs, lhs, flip_operator(operator))
          end

          # Case 2: Binding that evaluates to literal compared against impossible value
          if lhs.is_a?(Binding) && rhs.is_a?(Literal)
            return binding_literal_impossible?(lhs, rhs, operator)
          elsif rhs.is_a?(Binding) && lhs.is_a?(Literal)
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
