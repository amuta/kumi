# frozen_string_literal: true

# RESPONSIBILITY:
#   - Build the :dependency_graph and :leaf_map.
#   - Check for undefined references.
module Kumi
  module Analyzer
    module Passes
      class DependencyResolver < Visitor
        def initialize(schema, state)
          @schema = schema
          @state  = state
        end

        def run(errors)
          deps = Hash.new { |h, k| h[k] = Set.new }
          raw_leaves = Hash.new { |h, k| h[k] = Set.new }
          defs = @state[:definitions] || {}

          each_decl do |decl|
            refs = Set.new
            visit(decl) { |n| handle(n, decl, refs, raw_leaves, defs, errors) }
            deps[decl.name].merge(refs)
          end

          @state[:dependency_graph] = deps.transform_values(&:freeze).freeze
          @state[:leaf_map] = raw_leaves.transform_values(&:freeze).freeze
        end

        private

        def handle(node, decl, refs, leaves, defs, errors)
          case node
          when Binding
            errors << [node.loc, "undefined reference to `#{node.name}`"] unless defs.key?(node.name)
            refs << node.name
          when Field, Literal
            leaves[decl.name] << node
          end
        end

        def each_decl(&b)
          @schema.attributes.each(&b)
          @schema.traits.each(&b)
        end
      end
    end
  end
end
