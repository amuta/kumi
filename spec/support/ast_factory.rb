# frozen_string_literal: true

module ASTFactory
  module_function # expose module-functions only

  S = Kumi::Syntax

  # Dispatch table:  tag symbol → lambda(*args, loc:) → node instance
  NODE = {
    literal: ->(value, loc:) { S::Literal.new(value, loc: loc) },
    field: ->(name, loc:) { S::Field.new(name, loc: loc) },
    binding_ref: ->(name, loc:) { S::Binding.new(name, loc: loc) },

    call_expression: ->(fn_name, *args, loc:) { S::CallExpression.new(fn_name, args, loc: loc) },

    attribute: ->(name, expr, loc:) { S::Attribute.new(name, expr, loc: loc) },
    trait: ->(name, predicate, loc:) { S::Trait.new(name, predicate, loc: loc) },

    cascade_expression: ->(cases, loc:) { S::CascadeExpression.new(cases, loc: loc) },
    when_case_expression: lambda { |predicate, then_expr, loc:|
      S::WhenCaseExpression.new(predicate, then_expr, loc: loc)
    },

    # Root and Location are special because they are used in the
    # ASTFactory constructor to build the initial Root.
    # They are not used in the AST itself.

    root: ->(attributes = [], traits = [], loc:) { S::Root.new(attributes, traits, loc: loc) },

    location: ->(file, line, column) { S::Location.new(file: file, line: line, column: column) }
  }.freeze

  # Public constructor used in specs
  def syntax(kind, *args, loc: nil)
    builder = NODE[kind] or raise ArgumentError, "unknown node kind: #{kind.inspect}"
    builder.call(*args, loc: loc)
  end

  def loc(off = 0) = syntax(:location, __FILE__, __LINE__ + off)

  def attr(name, expr = syntax(:literal, 1, loc: loc))
    syntax(:attribute, name, expr, loc: loc)
  end

  def trait(name, predicate)
    syntax(:trait, name, predicate, loc: loc)
  end

  def binding_ref(name) = syntax(:binding_ref, name, loc: loc)
  alias ref binding_ref

  def call(fn_name, *args) = syntax(:call_expression, fn_name, *args, loc: loc)

  def lit(value) = syntax(:literal, value, loc: loc)

  def field(name) = syntax(:field, name, loc: loc)
  alias key field
  #
  # def Root(attrs = [], traits = [])
  #   # syntax(:Root, attrs, traits, loc: loc)
  # end

  def when_case_expression(predicate, then_expr)
    syntax(:when_case_expression, predicate, then_expr, loc: loc)
  end

  # Dependency graph factory methods for analyzer pass tests
  def dependency_edge(to:, type: :ref, via: nil)
    Kumi::Analyzer::Passes::DependencyResolver::DependencyEdge.new(
      to: to, type: type, via: via
    )
  end

  def dependency_graph(**nodes)
    nodes.transform_values do |edges|
      Array(edges).map do |edge_spec|
        case edge_spec
        when Symbol
          dependency_edge(to: edge_spec)
        when Hash
          dependency_edge(**edge_spec)
        when Kumi::Analyzer::Passes::DependencyResolver::DependencyEdge
          edge_spec
        else
          raise ArgumentError, "Invalid edge specification: #{edge_spec}"
        end
      end
    end
  end
end
