# frozen_string_literal: true

module ASTFactory
  module_function # expose module-functions only

  include Kumi::Syntax

  # Dispatch table:  tag symbol → lambda(*args, loc:) → node instance
  NODE = {
    literal: ->(value, loc:) { Literal.new(value, loc: loc) },
    input_ref: ->(name, loc:) { InputReference.new(name, loc: loc) },
    input_elem_ref: ->(path, loc:) { InputElementReference.new(path, loc: loc) },
    declaration_ref: ->(name, loc:) { DeclarationReference.new(name, loc: loc) },
    input_decl: ->(name, domain = nil, type = nil, children = [], access_mode = nil, loc:) { InputDeclaration.new(name, domain, type, children, access_mode, loc: loc) },

    call_expr: ->(fn_name, *args, loc:) { CallExpression.new(fn_name, args, loc: loc) },

    value_decl: ->(name, expr, loc:) { ValueDeclaration.new(name, expr, loc: loc) },
    trait_decl: ->(name, trait, loc:) { TraitDeclaration.new(name, trait, loc: loc) },

    cascade_expr: ->(cases, loc:) { CascadeExpression.new(cases, loc: loc) },
    case_expr: lambda { |trait, then_expr, loc:|
      CaseExpression.new(trait, then_expr, loc: loc)
    },

    array_expr: ->(elements, loc:) { ArrayExpression.new(elements, loc: loc) },
    hash_expr: ->(pairs, loc:) { HashExpression.new(pairs, loc: loc) },

    # Root and Location are special because they are used in the
    # ASTFactory constructor to build the initial Root.
    # They are not used in the AST itself.

    root: ->(inputs = [], attributes = [], traits = [], loc:) { Root.new(inputs, attributes, traits, loc: loc) },

    location: ->(file, line, column) { Location.new(file: file, line: line, column: column) }
  }.freeze

  # Public constructor used in specs
  def syntax(kind, *args, loc: nil)
    builder = NODE[kind] or raise ArgumentError, "unknown node kind: #{kind.inspect}"
    builder.call(*args, loc: loc)
  end

  def loc(off = 0) = syntax(:location, __FILE__, __LINE__ + off)

  def attr(name, expr = syntax(:literal, 1, loc: loc))
    syntax(:value_decl, name, expr, loc: loc)
  end

  def trait(name, trait)
    syntax(:trait_decl, name, trait, loc: loc)
  end

  def binding_ref(name) = syntax(:declaration_ref, name, loc: loc)
  alias ref binding_ref
  alias declaration_ref binding_ref

  def call(fn_name, *args) = syntax(:call_expr, fn_name, *args, loc: loc)

  def lit(value) = syntax(:literal, value, loc: loc)

  def input_ref(name) = syntax(:input_ref, name, loc: loc)
  alias field_ref input_ref

  def input_elem_ref(path) = syntax(:input_elem_ref, path, loc: loc)

  def input_decl(name, type = nil, domain = nil, children: [], access_mode: nil) = syntax(:input_decl, name, domain, type, children, access_mode, loc: loc)
  alias field_decl input_decl

  def when_case_expression(trait, then_expr)
    syntax(:case_expr, trait, then_expr, loc: loc)
  end
  alias case_expr when_case_expression

  # Dependency graph factory methods for analyzer pass tests
  def dependency_edge(to:, type: :ref, via: nil)
    Kumi::Core::Analyzer::Passes::DependencyResolver::DependencyEdge.new(
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
        when Kumi::Core::Analyzer::Passes::DependencyResolver::DependencyEdge
          edge_spec
        else
          raise ArgumentError, "Invalid edge specification: #{edge_spec}"
        end
      end
    end
  end
end
