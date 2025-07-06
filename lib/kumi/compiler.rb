# Kumi::Compiler
#
# RESPONSIBILITY
#   • Turn a validated Schema + Analyzer result into executable lambdas.
#   • Respect the Analyzer's topo_order so bindings are compiled once
#     their dependencies are available.
#
# PUBLIC INTERFACE
#   .compile(schema, analyzer:) → Kumi::CompiledSchema

module Kumi
  class Compiler
    def self.compile(schema, analyzer:)
      new(schema, analyzer).compile
    end

    def initialize(schema, analyzer)
      @schema   = schema
      @analysis = analyzer     # Kumi::Analyzer::Result
      @bindings = {}           # name → [:attr|:trait, lambda]
    end

    def compile
      build_index

      @analysis.topo_order.each do |name|
        decl = @index[name] || raise("Unknown binding #{name}")
        compile_declaration(decl)
      end

      CompiledSchema.new(@bindings.freeze)
    end

    private

    def build_index
      @index = {}
      @schema.attributes.each { |a| @index[a.name] = a }
      @schema.traits.each     { |t| @index[t.name] = t }
    end

    def compile_declaration(decl)
      kind   = decl.is_a?(Kumi::Syntax::Trait) ? :trait : :attr
      fn     = compile_expr(decl.expression)
      @bindings[decl.name] = [kind, fn]
    end

    # Expression compiler returns a lambda(ctx) for every node
    def compile_expr(expr)
      case expr
      when Kumi::Syntax::Literal
        v = expr.value
        ->(_ctx) { v }

      when Kumi::Syntax::Field
        compile_field(expr)

      when Kumi::Syntax::Binding
        name = expr.name
        ->(ctx) { @bindings.fetch(name).last.call(ctx) }

      when Kumi::Syntax::ListExpression
        fns = expr.elements.map { |e| compile_expr(e) }
        ->(ctx) { fns.map { |fn| fn.call(ctx) } }

      when Kumi::Syntax::CallExpression
        fn_name = expr.fn_name
        arg_fns = expr.args.map { |a| compile_expr(a) }
        ->(ctx) { invoke_function(fn_name, arg_fns, ctx, expr.loc) }

      when Kumi::Syntax::CascadeExpression
        pairs = expr.cases.map { |c| [compile_expr(c.condition), compile_expr(c.result)] }
        lambda { |ctx|
          pairs.each { |cond, res| return res.call(ctx) if cond.call(ctx) }
          nil
        }

      when Kumi::Syntax::WhenCaseExpression
        raise "WhenCaseExpression should appear only inside CascadeExpression"

      else
        raise "Unsupported expression node: #{expr.class}"
      end
    end

    # Helpers
    def compile_field(node)
      name = node.name
      loc  = node.loc
      lambda do |ctx|
        next ctx[name] if ctx.respond_to?(:key?) && ctx.key?(name)

        raise Kumi::Errors::RuntimeError,
              "Key '#{name}' not found at #{loc}. Available: #{ctx.respond_to?(:keys) ? ctx.keys.join(", ") : "N/A"}"
      end
    end

    def invoke_function(name, arg_fns, ctx, loc)
      fn = Kumi::MethodCallRegistry.fetch(name)
      arg_values = arg_fns.map { |fn| fn.call(ctx) }
      fn.call(*arg_values)
    rescue StandardError => e
      raise Kumi::Errors::RuntimeError,
            "Error calling fn(:#{name}) at #{loc}: #{e.message}"
    end
  end
end
