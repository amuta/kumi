# frozen_string_literal: true

module Kumi
  module StrictCycleChecker
    Atom = Struct.new(:op, :lhs, :rhs)           # :> or :<
    Edge = Struct.new(:from, :to)                # directed, strict

    module_function

    def unsat?(atoms, debug: false)
      # Check numerical contradictions first (bound tables approach)
      return true if numerical_contradiction?(atoms, debug: debug)

      # Check equality contradictions
      return true if equality_contradiction?(atoms, debug: debug)

      # Check strict inequality cycles (DFS approach)
      edges = atoms.filter_map { |a| to_edge(a) }
      puts "edges: #{edges.map { |e| "#{e.from}→#{e.to}" }.join(', ')}" if debug
      cycle?(build_graph(edges), debug: debug)
    end

    # Simplified bound-checking approach for numerical contradictions
    def numerical_contradiction?(atoms, debug: false)
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

    def extract_symbol_numeric_pair(atom)
      if atom.lhs.is_a?(Symbol) && atom.rhs.is_a?(Numeric)
        [atom.lhs, atom.rhs, atom.op]
      elsif atom.rhs.is_a?(Symbol) && atom.lhs.is_a?(Numeric)
        [atom.rhs, atom.lhs, flip_operator(atom.op)]
      else
        [nil, nil, nil]
      end
    end

    def update_bounds(lowers, uppers, sym, num, operator)
      case operator
      when :> then lowers[sym] = [lowers[sym], num + 1].max # x > 5 means x >= 6
      when :>= then lowers[sym] = [lowers[sym], num].max      # x >= 5 means x >= 5
      when :< then uppers[sym] = [uppers[sym], num - 1].min   # x < 5 means x <= 4
      when :<= then uppers[sym] = [uppers[sym], num].min      # x <= 5 means x <= 5
      end
    end

    def flip_operator(operator)
      { :> => :<, :>= => :<=, :< => :>, :<= => :>= }[operator]
    end

    # Equality contradiction detection
    def equality_contradiction?(atoms, debug: false)
      equal_pairs, strict_pairs = collect_equality_pairs(atoms)

      return true if direct_equality_contradiction?(equal_pairs, strict_pairs, debug)

      transitive_equality_contradiction?(equal_pairs, strict_pairs, debug)
    end

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

    def direct_equality_contradiction?(equal_pairs, strict_pairs, debug)
      conflicting_pairs = equal_pairs & strict_pairs
      return false unless conflicting_pairs.any?

      puts "equality contradiction detected" if debug
      true
    end

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

    def build_equivalence_classes(equal_pairs)
      parent = Hash.new { |h, k| h[k] = k }

      equal_pairs.each do |pair|
        root1 = find_root(pair[0], parent)
        root2 = find_root(pair[1], parent)
        parent[root1] = root2
      end

      group_variables_by_root(parent)
    end

    def find_root(element, parent)
      return element if parent[element] == element

      parent[element] = find_root(parent[element], parent)
      parent[element]
    end

    def group_variables_by_root(parent)
      groups = Hash.new { |h, k| h[k] = [] }
      parent.each_key do |var|
        groups[find_root(var, parent)] << var
      end
      groups.values.select { |group| group.size > 1 }
    end

    # --- helpers -----------------------------------------------------------

    def to_edge(atom)
      case atom.op
      when :> then Edge.new(atom.rhs, atom.lhs)  # x>y ⇒ y→x
      when :< then Edge.new(atom.lhs, atom.rhs)  # x<y ⇒ x→y
      end
    end

    def build_graph(edges)
      edges.each_with_object(Hash.new { |h, k| h[k] = [] }) do |e, g|
        g[e.from] << e.to
      end
    end

    # DFS with colouring; true when strict cycle found
    def cycle?(graph, debug:)
      colour = Hash.new(:white)
      stack  = []

      graph.keys.any? { |vertex| colour[vertex] == :white && dfs_visit?(vertex, colour, stack, graph, debug) }
    end

    def dfs_visit?(vertex, colour, stack, graph, debug)
      colour[vertex] = :gray
      stack.push(vertex)
      graph[vertex].each do |neighbor|
        return report_cycle?(stack + [neighbor], debug) if colour[neighbor] == :gray
        return true if colour[neighbor] == :white && dfs_visit?(neighbor, colour, stack, graph, debug)
      end
      stack.pop
      colour[vertex] = :black
      false
    end

    def report_cycle?(path, debug)
      puts "cycle: #{path.join(' > ')}" if debug
      true
    end
  end
end
