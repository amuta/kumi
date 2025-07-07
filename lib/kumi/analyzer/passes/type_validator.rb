# frozen_string_literal: true

# RESPONSIBILITY
#   • Local semantic checks
#   • Build :dependency_graph and :leaf_map
# INTERFACE
#   new(schema, state).run(errors)

module Kumi
  module Analyzer
    module Passes
      class TypeValidator < Visitor
        include Kumi::Syntax

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

        def each_decl(&b)
          @schema.attributes.each(&b)
          @schema.traits.each(&b)
        end

        def handle(node, decl, refs, leaves, defs, errors)
          case node
          when Syntax::Attribute
            errors << [node.loc, "attribute `#{node.name}` requires an expression"] if node.expression.nil?
          when Syntax::Trait
            unless node.expression.is_a?(Syntax::Expressions::CallExpression)
              errors << [node.loc, "trait `#{node.name}` must wrap a CallExpression"]
            end
          when Syntax::TerminalExpressions::Binding
            errors << [node.loc, "undefined reference to `#{node.name}`"] unless defs.key?(node.name)
            refs << node.name
          when Syntax::Expressions::CallExpression
            validate_call(node, errors)
          when Syntax::TerminalExpressions::Field
            leaves[decl.name] << node
          when Syntax::TerminalExpressions::Literal
            leaves[decl.name] << node
          end
        end

        def validate_call(node, errors)
          MethodCallRegistry.confirm_support!(node.fn_name)
          sig = MethodCallRegistry.signature(node.fn_name)
          if sig[:arity] >= 0 && sig[:arity] != node.args.size
            errors << [node.loc, "operator `#{node.fn_name}` expects #{sig[:arity]} args, got #{node.args.size}"]
          end
        rescue MethodCallRegistry::UnknownMethodName
          errors << [node.loc, "unsupported operator `#{node.fn_name}`"]
        end
      end
    end
  end
end
