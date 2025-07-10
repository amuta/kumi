# frozen_string_literal: true

module Kumi
  Runner = Struct.new(:context, :schema, :node_index) do
    def slice(*keys)
      schema.evaluate(context, *keys)
    end

    def fetch(key)
      schema.evaluate_binding(key, context)
    end

    def explain(key, indent = 0)
      indent_str = "  " * indent

      # Find the starting AST node for the key.
      node = node_index[key]
      return "#{indent_str}-> :#{key} is a raw input with value: #{context[key].inspect}" unless node

      # Start the recursive explanation from the node's expression.
      "#{indent_str}-> :#{key} evaluated to: #{fetch(key).inspect}\n" + explain_expression(node.expression, indent + 1)
    end

    private

    # This new recursive helper walks the AST.
    def explain_expression(expr, indent)
      indent_str = "  " * indent

      case expr
      when Syntax::Expressions::CallExpression
        # Explain the function call and its arguments.
        output = "#{indent_str}- is fn(:#{expr.fn_name}) with arguments:\n"
        expr.args.each do |arg|
          output += explain_expression(arg, indent + 1)
        end
        output
      when Syntax::TerminalExpressions::Binding
        # Recursively explain the dependency.
        "#{indent_str}- references another rule:\n" + explain(expr.name, indent + 1)
      when Syntax::TerminalExpressions::Field
        "#{indent_str}- is key(:#{expr.name}) with value: #{context[expr.name].inspect}\n"
      when Syntax::TerminalExpressions::Literal
        "#{indent_str}- is the literal value: #{expr.value.inspect}\n"
      when Syntax::Expressions::CascadeExpression
        # Find which 'on' clause was triggered.
        # This logic can be further enhanced to be more detailed.
        "#{indent_str}- is a cascade expression.\n"
      else
        "#{indent_str}- is an unknown expression type.\n"
      end
    rescue StandardError => e
      binding.pry
    end
  end
end
