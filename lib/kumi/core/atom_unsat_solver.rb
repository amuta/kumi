# frozen_string_literal: true

module Kumi
  module Core
    # AtomUnsatSolver detects logical contradictions in constraint systems using three analysis passes:
    # 1. Numerical bounds checking for symbol-numeric inequalities (e.g. x > 5, x < 3)
    # 2. Equality contradiction detection for same-type comparisons
    # 3. Strict inequality cycle detection using Kahn's topological sort (stack-safe)
    #
    # @example Basic usage
    #   atoms = [Atom.new(:>, :x, 5), Atom.new(:<, :x, 3)]
    #   AtomUnsatSolver.unsat?(atoms) #=> true (contradiction: x > 5 AND x < 3)
    #
    # @example Cycle detection
    #   atoms = [Atom.new(:<, :x, :y), Atom.new(:<, :y, :z), Atom.new(:<, :z, :x)]
    #   AtomUnsatSolver.unsat?(atoms) #=> true (cycle: x < y < z < x)
    module AtomUnsatSolver
      # Represents a constraint atom with operator and operands
      # @!attribute [r] op
      #   @return [Symbol] comparison operator (:>, :<, :>=, :<=, :==)
      # @!attribute [r] lhs
      #   @return [Object] left-hand side operand
      # @!attribute [r] rhs
      #   @return [Object] right-hand side operand
      Atom = Struct.new(:op, :lhs, :rhs)

      # Represents a directed edge in the strict inequality graph
      # @!attribute [r] from
      #   @return [Symbol] source vertex
      # @!attribute [r] to
      #   @return [Symbol] target vertex
      Edge = Struct.new(:from, :to)

      module_function

      # Main entry point: checks if the given constraint atoms are unsatisfiable
      #
      # @param atoms [Array<Atom>] constraint atoms to analyze
      # @param debug [Boolean] enable debug output
      # @return [Boolean] true if constraints are unsatisfiable
      def unsat?(atoms, debug: false)
        # Pass 0: Check for special impossible atoms (domain violations, etc.)
        return true if impossible_atoms_exist?(atoms, debug: debug)

        # Pass 1: Check numerical bound contradictions (symbol vs numeric)
        return true if numerical_contradiction?(atoms, debug: debug)

        # Pass 2: Check equality contradictions (same-type comparisons)
        return true if equality_contradiction?(atoms, debug: debug)

        # Pass 3: Check strict inequality cycles using stack-safe Kahn's algorithm
        edges = build_strict_inequality_edges(atoms)
        puts "edges: #{edges.map { |e| "#{e.from}→#{e.to}" }.join(', ')}" if debug

        StrictInequalitySolver.cycle?(edges, debug: debug)
      end

      # Pass 0: Detects special impossible atoms (domain violations, etc.)
      # These atoms are created by UnsatDetector when it finds statically impossible constraints
      #
      # @param atoms [Array<Atom>] constraint atoms
      # @param debug [Boolean] enable debug output
      # @return [Boolean] true if impossible atoms exist
      def impossible_atoms_exist?(atoms, debug: false)
        impossible_found = atoms.any? do |atom|
          atom.lhs == :__impossible__ || atom.rhs == :__impossible__
        end

        puts "impossible atom detected (domain violation or static impossibility)" if impossible_found && debug
        impossible_found
      end

      # Pass 1: Detects numerical bound contradictions using interval analysis
      # Handles cases like x > 5 AND x < 3 (contradictory bounds)
      # Also detects always-false comparisons like 100 < 100 or 5 > 5
      #
      # @param atoms [Array<Atom>] constraint atoms
      # @param debug [Boolean] enable debug output
      # @return [Boolean] true if numerical contradiction exists
      def numerical_contradiction?(atoms, debug: false)
        return true if always_false_constraints_exist?(atoms, debug)

        check_bound_contradictions(atoms, debug)
      end

      def always_false_constraints_exist?(atoms, debug)
        atoms.any? do |atom|
          next false unless always_false_comparison?(atom)

          puts "always-false comparison detected: #{atom.lhs} #{atom.op} #{atom.rhs}" if debug
          true
        end
      end

      def check_bound_contradictions(atoms, debug)
        lowers = Hash.new(-Float::INFINITY)
        uppers = Hash.new(Float::INFINITY)

        atoms.each do |atom|
          sym, num, op = extract_symbol_numeric_pair(atom)
          next unless sym

          update_bounds(lowers, uppers, sym, num, op)
        end

        contradiction = uppers.any? { |sym, hi| hi < lowers[sym] }
        puts "numerical contradiction detected" if contradiction && debug
        contradiction
      end

      # Pass 2: Detects equality contradictions using union-find equivalence classes
      # Handles cases like x == y AND x > y (equality vs strict inequality)
      #
      # @param atoms [Array<Atom>] constraint atoms
      # @param debug [Boolean] enable debug output
      # @return [Boolean] true if equality contradiction exists
      def equality_contradiction?(atoms, debug: false)
        equal_pairs, strict_pairs = collect_equality_pairs(atoms)

        return true if direct_equality_contradiction?(equal_pairs, strict_pairs, debug)
        return true if conflicting_equalities?(atoms, debug: debug)

        transitive_equality_contradiction?(equal_pairs, strict_pairs, debug)
      end

      # Extracts symbol-numeric pairs and normalizes operator direction
      # @param atom [Atom] constraint atom
      # @return [Array(Symbol, Numeric, Symbol)] normalized [symbol, number, operator] or [nil, nil, nil]
      def extract_symbol_numeric_pair(atom)
        if atom.lhs.is_a?(Symbol) && atom.rhs.is_a?(Numeric)
          [atom.lhs, atom.rhs, atom.op]
        elsif atom.rhs.is_a?(Symbol) && atom.lhs.is_a?(Numeric)
          [atom.rhs, atom.lhs, flip_operator(atom.op)]
        else
          [nil, nil, nil]
        end
      end

      # Updates variable bounds based on constraint
      # @param lowers [Hash] lower bounds by symbol
      # @param uppers [Hash] upper bounds by symbol
      # @param sym [Symbol] variable symbol
      # @param num [Numeric] constraint value
      # @param operator [Symbol] constraint operator
      def update_bounds(lowers, uppers, sym, num, operator)
        case operator
        when :> then lowers[sym] = [lowers[sym], num + 1].max # x > 5 means x >= 6
        when :>= then lowers[sym] = [lowers[sym], num].max      # x >= 5 means x >= 5
        when :< then uppers[sym] = [uppers[sym], num - 1].min   # x < 5 means x <= 4
        when :<= then uppers[sym] = [uppers[sym], num].min      # x <= 5 means x <= 5
        end
      end

      # Flips comparison operator for normalization
      # @param operator [Symbol] original operator
      # @return [Symbol] flipped operator
      def flip_operator(operator)
        { :> => :<, :>= => :<=, :< => :>, :<= => :>= }[operator]
      end

      # Detects always-false comparisons like 5 > 5, 100 < 100, etc.
      # These represent impossible conditions since they can never be true
      # @param atom [Atom] constraint atom to check
      # @return [Boolean] true if comparison is always false
      def always_false_comparison?(atom)
        return false unless atom.lhs.is_a?(Numeric) && atom.rhs.is_a?(Numeric)

        lhs = atom.lhs
        rhs = atom.rhs
        case atom.op
        when :> then lhs <= rhs    # 5 > 5 is always false
        when :< then lhs >= rhs    # 5 < 5 is always false
        when :>= then lhs < rhs    # 5 >= 6 is always false
        when :<= then lhs > rhs    # 6 <= 5 is always false
        when :== then lhs != rhs   # 5 == 6 is always false
        when :!= then lhs == rhs   # 5 != 5 is always false
        else false
        end
      end

      # Builds directed edges for strict inequality cycle detection
      # Only creates edges when both endpoints are symbols (variables)
      # Filters out symbol-numeric pairs (handled by numerical_contradiction?)
      #
      # @param atoms [Array<Atom>] constraint atoms
      # @return [Array<Edge>] directed edges for cycle detection
      def build_strict_inequality_edges(atoms)
        atoms.filter_map do |atom|
          next unless atom.lhs.is_a?(Symbol) && atom.rhs.is_a?(Symbol)

          case atom.op
          when :> then Edge.new(atom.rhs, atom.lhs)  # x > y ⇒ edge y → x
          when :< then Edge.new(atom.lhs, atom.rhs)  # x < y ⇒ edge x → y
          end
        end
      end

      # Collects equality and strict inequality pairs for same-type operands
      # @param atoms [Array<Atom>] constraint atoms
      # @return [Array(Set, Set)] [equality pairs, strict inequality pairs]
      def collect_equality_pairs(atoms)
        equal_pairs = Set.new
        strict_pairs = Set.new

        atoms.each do |atom|
          next unless atom.lhs.instance_of?(atom.rhs.class)

          pair = [atom.lhs, atom.rhs].sort
          case atom.op
          when :==
            equal_pairs << pair
          when :>, :<
            strict_pairs << pair
          end
        end

        [equal_pairs, strict_pairs]
      end

      # Checks for direct equality contradictions (x == y AND x > y)
      # @param equal_pairs [Set] equality constraint pairs
      # @param strict_pairs [Set] strict inequality pairs
      # @param debug [Boolean] enable debug output
      # @return [Boolean] true if direct contradiction exists
      def direct_equality_contradiction?(equal_pairs, strict_pairs, debug)
        conflicting_pairs = equal_pairs & strict_pairs
        return false unless conflicting_pairs.any?

        puts "equality contradiction detected" if debug
        true
      end

      # Checks for conflicting equalities (x == a AND x == b where a != b)
      # @param atoms [Array<Atom>] constraint atoms
      # @param debug [Boolean] enable debug output
      # @return [Boolean] true if conflicting equalities exist
      def conflicting_equalities?(atoms, debug: false)
        equalities = atoms.select { |atom| atom.op == :== }

        # Group equalities by their left-hand side
        by_lhs = equalities.group_by(&:lhs)

        # Check each variable for conflicting equality constraints
        by_lhs.each do |lhs, atoms_for_lhs|
          next if atoms_for_lhs.size < 2

          # Get all values this variable is constrained to equal
          values = atoms_for_lhs.map(&:rhs).uniq

          if values.size > 1
            puts "conflicting equalities detected: #{lhs} == #{values.join(" AND #{lhs} == ")}" if debug
            return true
          end
        end

        false
      end

      # Checks for transitive equality contradictions using union-find
      # @param equal_pairs [Set] equality constraint pairs
      # @param strict_pairs [Set] strict inequality pairs
      # @param debug [Boolean] enable debug output
      # @return [Boolean] true if transitive contradiction exists
      def transitive_equality_contradiction?(equal_pairs, strict_pairs, debug)
        equiv_classes = build_equivalence_classes(equal_pairs)
        equiv_classes.each do |equiv_class|
          equiv_class.combination(2).each do |var1, var2|
            pair = [var1, var2].sort
            next unless strict_pairs.include?(pair)

            puts "transitive equality contradiction detected" if debug
            return true
          end
        end
        false
      end

      # Builds equivalence classes using union-find algorithm
      # @param equal_pairs [Set] equality constraint pairs
      # @return [Array<Array>] equivalence classes (groups of equal variables)
      def build_equivalence_classes(equal_pairs)
        parent = Hash.new { |h, k| h[k] = k }

        equal_pairs.each do |pair|
          root1 = find_root(pair[0], parent)
          root2 = find_root(pair[1], parent)
          parent[root1] = root2
        end

        group_variables_by_root(parent)
      end

      # Finds root of equivalence class with path compression
      # @param element [Object] element to find root for
      # @param parent [Hash] parent pointers for union-find
      # @return [Object] root element of equivalence class
      def find_root(element, parent)
        return element if parent[element] == element

        parent[element] = find_root(parent[element], parent)
        parent[element]
      end

      # Groups variables by their equivalence class root
      # @param parent [Hash] parent pointers for union-find
      # @return [Array<Array>] equivalence classes with multiple elements
      def group_variables_by_root(parent)
        groups = Hash.new { |h, k| h[k] = [] }
        parent.each_key do |var|
          groups[find_root(var, parent)] << var
        end
        groups.values.select { |group| group.size > 1 }
      end
    end

    # Stack-safe strict inequality cycle detector using Kahn's topological sort algorithm
    #
    # This module implements iterative cycle detection to avoid SystemStackError on deep graphs.
    # Uses Kahn's algorithm: if topological sort cannot order all vertices, a cycle exists.
    module StrictInequalitySolver
      module_function

      # Detects cycles in directed graph using stack-safe Kahn's topological sort
      #
      # @param edges [Array<Edge>] directed edges representing strict inequalities
      # @param debug [Boolean] enable debug output
      # @return [Boolean] true if cycle exists
      def cycle?(edges, debug: false)
        return false if edges.empty?

        graph, in_degree = build_graph_with_degrees(edges)
        processed_count = kahns_algorithm(graph, in_degree)

        detect_cycle_from_processing_count(processed_count, graph.size, debug)
      end

      def kahns_algorithm(graph, in_degree)
        queue = graph.keys.select { |v| in_degree[v].zero? }
        processed_count = 0

        until queue.empty?
          vertex = queue.shift
          processed_count += 1

          graph[vertex].each do |neighbor|
            in_degree[neighbor] -= 1
            queue << neighbor if in_degree[neighbor].zero?
          end
        end

        processed_count
      end

      def detect_cycle_from_processing_count(processed_count, total_vertices, debug)
        has_cycle = processed_count < total_vertices
        puts "cycle detected in strict inequality graph" if has_cycle && debug
        has_cycle
      end

      # Builds adjacency list graph and in-degree counts from edges
      # Pre-populates all vertices (including those with no outgoing edges) to avoid mutation during iteration
      #
      # @param edges [Array<Edge>] directed edges
      # @return [Array(Hash, Hash)] [adjacency_list, in_degree_counts]
      def build_graph_with_degrees(edges)
        vertices = collect_all_vertices(edges)
        graph, in_degree = initialize_graph_structures(vertices)
        populate_graph_data(edges, graph, in_degree)
        [graph, in_degree]
      end

      def collect_all_vertices(edges)
        vertices = Set.new
        edges.each { |e| vertices << e.from << e.to }
        vertices
      end

      def initialize_graph_structures(vertices)
        graph = Hash.new { |h, k| h[k] = [] }
        in_degree = Hash.new(0)
        vertices.each do |v|
          graph[v]
          in_degree[v] = 0
        end
        [graph, in_degree]
      end

      def populate_graph_data(edges, graph, in_degree)
        edges.each do |edge|
          graph[edge.from] << edge.to
          in_degree[edge.to] += 1
        end
      end
    end
  end
end
