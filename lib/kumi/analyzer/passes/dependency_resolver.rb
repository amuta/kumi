# frozen_string_literal: true

module Kumi
  module Analyzer
    module Passes
      # RESPONSIBILITY: Build dependency graph and detect conditional dependencies in cascades
      # DEPENDENCIES: :declarations from NameIndexer, :inputs from InputCollector
      # PRODUCES: :dependencies, :dependents, :leaves - Dependency analysis results
      # INTERFACE: new(schema, state).run(errors)
      class DependencyResolver < PassBase
        # Enhanced edge with conditional flag and cascade metadata
        class DependencyEdge
          attr_reader :to, :type, :via, :conditional, :cascade_owner

          def initialize(to:, type:, via:, conditional: false, cascade_owner: nil)
            @to = to
            @type = type
            @via = via
            @conditional = conditional
            @cascade_owner = cascade_owner
          end
        end

        include Syntax

        def run(errors)
          definitions = get_state(:declarations)
          input_meta = get_state(:inputs)

          dependency_graph = Hash.new { |h, k| h[k] = [] }
          reverse_dependencies = Hash.new { |h, k| h[k] = [] }
          leaf_map = Hash.new { |h, k| h[k] = Set.new }

          each_decl do |decl|
            # Traverse the expression for each declaration, passing context down
            visit_with_context(decl.expression, { decl_name: decl.name }) do |node, context|
              process_node(node, decl, dependency_graph, reverse_dependencies, leaf_map, definitions, input_meta, errors, context)
            end
          end

          # Compute transitive closure of reverse dependencies
          transitive_dependents = compute_transitive_closure(reverse_dependencies)

          state.with(:dependencies, dependency_graph.transform_values(&:freeze).freeze)
               .with(:dependents, transitive_dependents.freeze)
               .with(:leaves, leaf_map.transform_values(&:freeze).freeze)
        end

        private

        def process_node(node, decl, graph, reverse_deps, leaves, definitions, input_meta, errors, context)
          case node
          when DeclarationReference
            report_error(errors, "undefined reference to `#{node.name}`", location: node.loc) unless definitions.key?(node.name)

            # Determine if this is a conditional dependency
            conditional = context[:in_cascade_branch] || context[:in_cascade_base] || false
            cascade_owner = conditional ? (context[:cascade_owner] || context[:decl_name]) : nil

            add_dependency_edge(graph, reverse_deps, decl.name, node.name, :ref, context[:via],
                                conditional: conditional,
                                cascade_owner: cascade_owner)
          when InputReference
            add_dependency_edge(graph, reverse_deps, decl.name, node.name, :key, context[:via])
            leaves[decl.name] << node
          when InputElementReference
            # adds the root input declaration as a dependency
            root_input_declr_name = node.path.first
            add_dependency_edge(graph, reverse_deps, decl.name, root_input_declr_name, :key, context[:via])
          when Literal
            leaves[decl.name] << node
          end
        end

        def add_dependency_edge(graph, reverse_deps, from, to, type, via, conditional: false, cascade_owner: nil)
          edge = DependencyEdge.new(
            to: to,
            type: type,
            via: via,
            conditional: conditional,
            cascade_owner: cascade_owner
          )
          graph[from] << edge
          reverse_deps[to] << from
        end

        # Custom visitor that understands cascade structure
        def visit_with_context(node, context = {}, &block)
          return unless node

          yield(node, context)

          case node
          when CascadeExpression
            # Visit condition nodes and result expressions (non-base cases)
            node.cases[0...-1].each do |when_case|
              if when_case.condition
                # Visit condition normally
                visit_with_context(when_case.condition, context, &block)
              end
              # Visit result expressions as conditional dependencies
              conditional_context = context.merge(in_cascade_branch: true, cascade_owner: context[:decl_name])
              visit_with_context(when_case.result, conditional_context, &block)
            end

            # Visit base case with conditional flag
            if node.cases.last
              base_context = context.merge(in_cascade_base: true)
              visit_with_context(node.cases.last.result, base_context, &block)
            end
          when CallExpression
            new_context = context.merge(via: node.fn_name)
            node.children.each { |child| visit_with_context(child, new_context, &block) }
          else
            node.children.each { |child| visit_with_context(child, context, &block) } if node.respond_to?(:children)
          end
        end

        def compute_transitive_closure(reverse_dependencies)
          transitive = {}
          all_keys = reverse_dependencies.keys

          all_keys.each do |key|
            visited = Set.new
            to_visit = [key]
            dependents = Set.new

            while to_visit.any?
              current = to_visit.shift
              next if visited.include?(current)

              visited.add(current)

              direct_dependents = reverse_dependencies[current] || []
              direct_dependents.each do |dependent|
                next if visited.include?(dependent)

                dependents << dependent
                to_visit << dependent
              end
            end

            transitive[key] = dependents.to_a
          end

          transitive
        end
      end
    end
  end
end
