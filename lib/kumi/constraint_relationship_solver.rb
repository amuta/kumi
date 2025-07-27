# frozen_string_literal: true

module Kumi
  # Enhanced constraint solver that can detect mathematical impossibilities
  # across dependency chains by tracking variable relationships.
  #
  # This solver extends the basic AtomUnsatSolver by:
  # 1. Building a graph of mathematical relationships between variables
  # 2. Iteratively propagating constraints through multi-step dependency chains
  # 3. Detecting contradictions that span multiple variables across complex relationships
  #
  # Capabilities:
  # - Single-step relationships: y = x + 10, x == 50, y == 40 (impossible)
  # - Multi-step chains: x -> y -> z -> w, with constraints on x and w
  # - Identity relationships: y = x, handles both bindings and field references
  # - Mathematical operations: add, subtract, multiply, divide
  # - Forward and reverse constraint propagation
  #
  # @example Multi-step chain detection
  #   # Given: v1 = seed + 1, v2 = v1 + 2, v3 = v2 + 3, seed == 0, v3 == 10
  #   # The solver detects this is impossible since v3 must equal 6
  module ConstraintRelationshipSolver
    # Represents a mathematical relationship between variables
    # @!attribute [r] target
    #   @return [Symbol] the dependent variable
    # @!attribute [r] operation
    #   @return [Symbol] the mathematical operation (:add, :subtract, :multiply, :divide)
    # @!attribute [r] operands
    #   @return [Array] the operands (variables or constants)
    Relationship = Struct.new(:target, :operation, :operands)

    # Represents a derived constraint from propagating through relationships
    # @!attribute [r] variable
    #   @return [Symbol] the variable being constrained
    # @!attribute [r] operation
    #   @return [Symbol] the constraint operation (:==, :>, :<, etc.)
    # @!attribute [r] value
    #   @return [Object] the constraint value
    # @!attribute [r] derivation_path
    #   @return [Array<Symbol>] the variables this constraint was derived through
    DerivedConstraint = Struct.new(:variable, :operation, :value, :derivation_path)

    module_function

    # Enhanced unsatisfiability check that includes relationship analysis
    #
    # @param atoms [Array<Atom>] basic constraint atoms
    # @param definitions [Hash] variable definitions for relationship building
    # @param input_meta [Hash] input field metadata with domain constraints
    # @param debug [Boolean] enable debug output
    # @return [Boolean] true if constraints are unsatisfiable
    def unsat?(atoms, definitions, input_meta: {}, debug: false)
      # First run the standard unsat solver
      return true if Kumi::AtomUnsatSolver.unsat?(atoms, debug: debug)

      # Then check for relationship-based contradictions
      relationships = build_relationships(definitions)
      return false if relationships.empty?

      # Check for range-based impossibilities
      return true if range_violation?(atoms, relationships, input_meta, debug: debug)

      # Propagate constraints through relationships
      derived_constraints = propagate_constraints(atoms, relationships, debug: debug)

      # Check if any derived constraints violate domain constraints
      return true if domain_constraint_violation?(derived_constraints, input_meta, debug: debug)

      # Check if any derived constraints create contradictions
      all_constraints = atoms + derived_constraints.map do |dc|
        Kumi::AtomUnsatSolver::Atom.new(dc.operation, dc.variable, dc.value)
      end

      Kumi::AtomUnsatSolver.unsat?(all_constraints, debug: debug)
    end

    # Builds mathematical relationships from variable definitions
    #
    # @param definitions [Hash] variable name to AST node mapping
    # @return [Array<Relationship>] mathematical relationships between variables
    def build_relationships(definitions)
      relationships = []

      definitions.each do |var_name, definition|
        next unless definition&.expression

        relationship = extract_relationship(var_name, definition.expression)
        relationships << relationship if relationship
      end

      relationships
    end

    # Extracts mathematical relationship from an AST expression
    #
    # @param target [Symbol] the variable being defined
    # @param expression [Object] the AST expression defining the variable
    # @return [Relationship, nil] the relationship or nil if not extractable
    def extract_relationship(target, expression)
      case expression
      when Kumi::Syntax::Expressions::CallExpression
        extract_call_relationship(target, expression)
      when Kumi::Syntax::TerminalExpressions::Binding
        # Simple alias: target = other_variable
        Relationship.new(target, :identity, [expression.name])
      when Kumi::Syntax::TerminalExpressions::FieldRef
        # Direct field reference: target = input.field
        # Create identity relationship so we can propagate constraints
        Relationship.new(target, :identity, [expression.name])
      end
    end

    # Extracts relationship from a function call expression
    #
    # @param target [Symbol] the variable being defined
    # @param call_expr [CallExpression] the function call expression
    # @return [Relationship, nil] the relationship or nil if not supported
    def extract_call_relationship(target, call_expr)
      case call_expr.fn_name
      when :add
        operands = extract_operands(call_expr.args)
        return nil unless operands

        Relationship.new(target, :add, operands)
      when :subtract
        operands = extract_operands(call_expr.args)
        return nil unless operands

        Relationship.new(target, :subtract, operands)
      when :multiply
        operands = extract_operands(call_expr.args)
        return nil unless operands

        Relationship.new(target, :multiply, operands)
      when :divide
        operands = extract_operands(call_expr.args)
        return nil unless operands

        Relationship.new(target, :divide, operands)
      else
        # Unsupported operation for relationship extraction
        nil
      end
    end

    # Extracts operands from function arguments
    #
    # @param args [Array] function call arguments
    # @return [Array, nil] operands (variables as symbols, constants as values) or nil if not extractable
    def extract_operands(args)
      return nil if args.empty?

      args.map do |arg|
        case arg
        when Kumi::Syntax::TerminalExpressions::Binding
          arg.name
        when Kumi::Syntax::TerminalExpressions::Literal
          arg.value
        when Kumi::Syntax::TerminalExpressions::FieldRef
          # Use the field name directly to match how atoms represent input fields
          arg.name
        else
          # Unknown operand type
          return nil
        end
      end
    end

    # Propagates constraints through mathematical relationships to derive new constraints
    # Uses iterative propagation to handle multi-step dependency chains
    #
    # @param atoms [Array<Atom>] original constraint atoms
    # @param relationships [Array<Relationship>] mathematical relationships
    # @param debug [Boolean] enable debug output
    # @return [Array<DerivedConstraint>] derived constraints
    def propagate_constraints(atoms, relationships, debug: false)
      all_derived_constraints = []
      current_atoms = atoms.dup
      max_iterations = relationships.size + 1 # Prevent infinite loops
      iteration = 0

      loop do
        iteration += 1
        constraint_map = build_constraint_map(current_atoms)
        round_derived = []

        # Forward propagation: from operand constraints to target constraints
        relationships.each do |rel|
          derived = derive_constraints_for_relationship(rel, constraint_map, debug: debug)
          round_derived.concat(derived)

          # Reverse propagation: from target constraints to operand constraints
          derived = reverse_derive_constraints(rel, constraint_map, debug: debug)
          round_derived.concat(derived)
        end

        # Check if we derived any new constraints this round
        new_constraints = round_derived.reject do |dc|
          # Check if this constraint already exists in current_atoms or all_derived_constraints
          existing_atom = current_atoms.find do |atom|
            atom.lhs == dc.variable && atom.op == dc.operation && atom.rhs == dc.value
          end
          existing_derived = all_derived_constraints.find do |existing_dc|
            existing_dc.variable == dc.variable &&
              existing_dc.operation == dc.operation &&
              existing_dc.value == dc.value
          end
          existing_atom || existing_derived
        end

        break if new_constraints.empty? || iteration > max_iterations

        puts "Iteration #{iteration}: derived #{new_constraints.size} new constraints" if debug

        # Add new constraints to our working set for next iteration
        new_atoms = new_constraints.map do |dc|
          Kumi::AtomUnsatSolver::Atom.new(dc.operation, dc.variable, dc.value)
        end
        current_atoms.concat(new_atoms)
        all_derived_constraints.concat(new_constraints)
      end

      puts "Total derived #{all_derived_constraints.size} constraints in #{iteration} iterations" if debug
      all_derived_constraints
    end

    # Builds a map from variables to their constraints
    #
    # @param atoms [Array<Atom>] constraint atoms
    # @return [Hash] variable name to array of constraints
    def build_constraint_map(atoms)
      constraint_map = Hash.new { |h, k| h[k] = [] }

      atoms.each do |atom|
        constraint_map[atom.lhs] << atom if atom.lhs.is_a?(Symbol)
      end

      constraint_map
    end

    # Derives constraints on target variable from operand constraints
    #
    # @param relationship [Relationship] the mathematical relationship
    # @param constraint_map [Hash] variable to constraints mapping
    # @param debug [Boolean] enable debug output
    # @return [Array<DerivedConstraint>] derived constraints on target
    def derive_constraints_for_relationship(relationship, constraint_map, debug: false)
      derived = []

      # Handle different operand patterns
      if relationship.operands.size == 2
        # Case 1: One variable and one constant (e.g., x + 5)
        var_operand = relationship.operands.find { |op| op.is_a?(Symbol) }
        const_operand = relationship.operands.find { |op| op.is_a?(Numeric) }

        if var_operand && const_operand && constraint_map[var_operand].any?
          constraint_map[var_operand].each do |constraint|
            next unless constraint.op == :==

            derived_value = apply_operation(relationship.operation, constraint.rhs, const_operand, var_operand == relationship.operands[0])
            next unless derived_value

            derived << DerivedConstraint.new(
              relationship.target,
              :==,
              derived_value,
              [var_operand]
            )
            puts "Derived: #{relationship.target} == #{derived_value} (from #{var_operand} == #{constraint.rhs})" if debug
          end
        end

        # Case 2: Two variables (e.g., x + y) - handle when one has an equality constraint
        var1 = relationship.operands[0] if relationship.operands[0].is_a?(Symbol)
        var2 = relationship.operands[1] if relationship.operands[1].is_a?(Symbol)

        if var1 && var2 && var1 != var2
          # If we have constraints on var1, try to derive constraints involving var2
          constraint_map[var1].each do |constraint|
            next unless constraint.op == :==

            # For now, only handle addition with two variables: target = var1 + var2
            # If var1 == value, then target == value + var2
            next unless relationship.operation == :add && constraint_map[var2].any?

            constraint_map[var2].each do |var2_constraint|
              next unless var2_constraint.op == :==

              derived_value = constraint.rhs + var2_constraint.rhs
              derived << DerivedConstraint.new(
                relationship.target,
                :==,
                derived_value,
                [var1, var2]
              )
              if debug
                puts "Derived: #{relationship.target} == #{derived_value} (from #{var1} == #{constraint.rhs} and #{var2} == #{var2_constraint.rhs})"
              end
            end
          end
        end
      elsif relationship.operands.size == 1
        # Case 3: Identity relationship (target = operand)
        operand = relationship.operands[0]
        if operand.is_a?(Symbol) && constraint_map[operand].any?
          constraint_map[operand].each do |constraint|
            next unless constraint.op == :==

            derived << DerivedConstraint.new(
              relationship.target,
              :==,
              constraint.rhs,
              [operand]
            )
            puts "Derived: #{relationship.target} == #{constraint.rhs} (identity from #{operand})" if debug
          end
        end
      end

      derived
    end

    # Derives constraints on operand variables from target constraints (reverse propagation)
    #
    # @param relationship [Relationship] the mathematical relationship
    # @param constraint_map [Hash] variable to constraints mapping
    # @param debug [Boolean] enable debug output
    # @return [Array<DerivedConstraint>] derived constraints on operands
    def reverse_derive_constraints(relationship, constraint_map, debug: false)
      derived = []

      # For simple operations with one variable and one constant
      if relationship.operands.size == 2
        var_operand = relationship.operands.find { |op| op.is_a?(Symbol) }
        const_operand = relationship.operands.find { |op| op.is_a?(Numeric) }

        if var_operand && const_operand && constraint_map[relationship.target].any?
          constraint_map[relationship.target].each do |constraint|
            next unless constraint.op == :==

            derived_value = reverse_operation(relationship.operation, constraint.rhs, const_operand,
                                              var_operand == relationship.operands[0])
            next unless derived_value

            derived << DerivedConstraint.new(
              var_operand,
              :==,
              derived_value,
              [relationship.target]
            )
            puts "Reverse derived: #{var_operand} == #{derived_value} (from #{relationship.target} == #{constraint.rhs})" if debug
          end
        end
      elsif relationship.operands.size == 1 && relationship.operation == :identity
        # Handle reverse propagation for identity relationships
        operand = relationship.operands[0]
        if operand.is_a?(Symbol) && constraint_map[relationship.target].any?
          constraint_map[relationship.target].each do |constraint|
            next unless constraint.op == :==

            derived << DerivedConstraint.new(
              operand,
              :==,
              constraint.rhs,
              [relationship.target]
            )
            puts "Reverse derived: #{operand} == #{constraint.rhs} (identity from #{relationship.target})" if debug
          end
        end
      end

      derived
    end

    # Applies mathematical operation to derive target value
    #
    # @param operation [Symbol] the operation (:add, :subtract, :multiply, :divide)
    # @param var_value [Numeric] the value of the variable operand
    # @param const_value [Numeric] the constant operand value
    # @param var_is_first [Boolean] whether variable is first operand
    # @return [Numeric, nil] the derived value or nil if not computable
    def apply_operation(operation, var_value, const_value, var_is_first)
      case operation
      when :add
        var_value + const_value
      when :subtract
        var_is_first ? var_value - const_value : const_value - var_value
      when :multiply
        var_value * const_value
      when :divide
        return nil if const_value.zero?

        var_is_first ? var_value / const_value : const_value / var_value
      end
    end

    # Applies reverse mathematical operation to derive operand value
    #
    # @param operation [Symbol] the operation (:add, :subtract, :multiply, :divide)
    # @param target_value [Numeric] the value of the target variable
    # @param const_value [Numeric] the constant operand value
    # @param var_is_first [Boolean] whether variable is first operand
    # @return [Numeric, nil] the derived operand value or nil if not computable
    def reverse_operation(operation, target_value, const_value, var_is_first)
      case operation
      when :add
        target_value - const_value
      when :subtract
        var_is_first ? target_value + const_value : const_value - target_value
      when :multiply
        return nil if const_value.zero?

        target_value / const_value
      when :divide
        var_is_first ? target_value * const_value : const_value / target_value
      end
    end

    # Checks for range violations through mathematical operations
    #
    # @param atoms [Array<Atom>] basic constraint atoms
    # @param relationships [Array<Relationship>] mathematical relationships
    # @param input_meta [Hash] input field metadata with domain constraints
    # @param debug [Boolean] enable debug output
    # @return [Boolean] true if range violation exists
    def range_violation?(atoms, relationships, input_meta, debug: false)
      return false if input_meta.empty?

      # Build range map for all variables
      range_map = build_range_map(relationships, input_meta, debug: debug)
      return false if range_map.empty?

      # Check if any constraint violates computed ranges
      atoms.each do |atom|
        next unless atom.lhs.is_a?(Symbol) && atom.rhs.is_a?(Numeric)
        next unless %i[> < >= <=].include?(atom.op)

        range = range_map[atom.lhs]
        next unless range

        if range_constraint_impossible?(range, atom.op, atom.rhs)
          puts "Range violation: #{atom.lhs} #{atom.op} #{atom.rhs} impossible with range #{range}" if debug
          return true
        end
      end

      false
    end

    # Builds a map of variable ranges based on mathematical relationships and input domains
    #
    # @param relationships [Array<Relationship>] mathematical relationships
    # @param input_meta [Hash] input field metadata with domain constraints
    # @param debug [Boolean] enable debug output
    # @return [Hash] variable name to range mapping
    def build_range_map(relationships, input_meta, debug: false)
      range_map = {}

      # Start with input field ranges
      input_meta.each do |field_name, meta|
        domain = meta[:domain]
        next unless domain.is_a?(Range) && domain.first.is_a?(Numeric) && domain.last.is_a?(Numeric)

        range_map[field_name] = domain
        puts "Input range: #{field_name} -> #{domain}" if debug
      end

      # Propagate ranges through mathematical relationships
      # Use iterative approach to handle chains
      max_iterations = relationships.size + 1
      iteration = 0

      loop do
        iteration += 1
        new_ranges = {}

        relationships.each do |rel|
          range = compute_range_for_relationship(rel, range_map)
          next unless range

          if range_map[rel.target] != range
            new_ranges[rel.target] = range
            puts "Computed range: #{rel.target} -> #{range} (from #{rel.operation})" if debug
          end
        end

        break if new_ranges.empty? || iteration > max_iterations

        range_map.merge!(new_ranges)
      end

      range_map
    end

    # Computes the range for a variable based on its mathematical relationship
    #
    # @param relationship [Relationship] the mathematical relationship
    # @param range_map [Hash] current variable to range mapping
    # @return [Range, nil] computed range or nil if not computable
    def compute_range_for_relationship(relationship, range_map)
      # Handle identity relationships (simple variable copy)
      if relationship.operation == :identity && relationship.operands.size == 1
        var_operand = relationship.operands.first
        return range_map[var_operand] if range_map.key?(var_operand)

        return nil
      end

      return nil unless relationship.operands.size == 2

      # Handle variable + constant pattern
      var_operand = relationship.operands.find { |op| op.is_a?(Symbol) }
      const_operand = relationship.operands.find { |op| op.is_a?(Numeric) }

      return nil unless var_operand && const_operand

      var_range = range_map[var_operand]
      return nil unless var_range

      transform_range(var_range, relationship.operation, const_operand, var_operand == relationship.operands[0])
    end

    # Transforms a range through a mathematical operation
    #
    # @param range [Range] the input range
    # @param operation [Symbol] the mathematical operation
    # @param constant [Numeric] the constant operand
    # @param var_is_first [Boolean] whether variable is first operand
    # @return [Range, nil] transformed range or nil if not computable
    def transform_range(range, operation, constant, var_is_first)
      min_val = range.first
      max_val = range.last

      case operation
      when :add
        (min_val + constant)..(max_val + constant)
      when :subtract
        if var_is_first
          (min_val - constant)..(max_val - constant)
        else
          (constant - max_val)..(constant - min_val)
        end
      when :multiply
        if constant >= 0
          (min_val * constant)..(max_val * constant)
        else
          (max_val * constant)..(min_val * constant)
        end
      when :divide
        return nil if constant.zero?

        if var_is_first
          if constant.positive?
            (min_val / constant)..(max_val / constant)
          else
            (max_val / constant)..(min_val / constant)
          end
        else
          # constant / range - more complex, skip for now
          nil
        end
      end
    end

    # Checks if a constraint is impossible given a variable's range
    #
    # @param range [Range] the variable's possible range
    # @param operator [Symbol] the constraint operator
    # @param value [Numeric] the constraint value
    # @return [Boolean] true if constraint is impossible
    def range_constraint_impossible?(range, operator, value)
      case operator
      when :>
        # x > value is impossible if max(x) <= value
        range.last <= value
      when :>=
        # x >= value is impossible if max(x) < value
        range.last < value
      when :<
        # x < value is impossible if min(x) >= value
        range.first >= value
      when :<=
        # x <= value is impossible if min(x) > value
        range.first > value
      else
        false
      end
    end

    # Checks if any derived constraints violate input field domain constraints
    #
    # @param derived_constraints [Array<DerivedConstraint>] constraints derived from relationships
    # @param input_meta [Hash] input field metadata with domain constraints
    # @param debug [Boolean] enable debug output
    # @return [Boolean] true if domain constraint violation exists
    def domain_constraint_violation?(derived_constraints, input_meta, debug: false)
      return false if input_meta.empty?

      derived_constraints.each do |constraint|
        # Only check equality constraints for now
        next unless constraint.operation == :==

        # Check if this variable corresponds to an input field with domain constraints
        field_meta = input_meta[constraint.variable]
        next unless field_meta&.dig(:domain)

        domain = field_meta[:domain]
        value = constraint.value

        if violates_domain?(value, domain)
          puts "Domain violation detected: #{constraint.variable} == #{value} violates domain #{domain.inspect}" if debug
          return true
        end
      end

      false
    end

    # Checks if a value violates a domain constraint
    #
    # @param value [Object] the value to check
    # @param domain [Range, Array, Proc] the domain constraint
    # @return [Boolean] true if value violates domain
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
  end
end
