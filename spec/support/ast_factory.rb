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

    # Schema and Location are special because they are used in the
    # ASTFactory constructor to build the initial schema.
    # They are not used in the AST itself.

    schema: ->(attributes = [], traits = [], loc:) { S::Schema.new(attributes, traits, loc: loc) },

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
  # def schema(attrs = [], traits = [])
  #   # syntax(:schema, attrs, traits, loc: loc)
  # end

  def when_case_expression(predicate, then_expr)
    syntax(:when_case_expression, predicate, then_expr, loc: loc)
  end
end
