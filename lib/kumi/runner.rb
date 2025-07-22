# frozen_string_literal: true

module Kumi
  # This is just a sketch of the Runner class
  # TODO: do an actual structured implementation, with
  # clear interface and formatted output.
  Runner = Struct.new(:context, :schema, :node_index) do
    def slice(*keys)
      schema.evaluate(context, *keys)
    end

    def input
      context
    end

    def fetch(*keys)
      @cache ||= {}

      # if only one key is provided, return it directly
      #
      return schema.evaluate(context) if keys.length == 0

      if keys.length == 1
        key = keys.first
        # Return the cached value if it exists.
        return @cache[key] if @cache.key?(key)

        # Otherwise, calculate it, store it in the cache, and then return it.
        @cache[key] = schema.evaluate_binding(key, context)
        @cache[key]

      else
        cached_keys = keys.select { |k| @cache.key?(k) }
        not_cached_keys = keys - cached_keys

        values = schema.evaluate(context, *not_cached_keys)

        keys.each do |key|
          # If the key is already cached, skip it
          next if @cache.key?(key)

          # Otherwise, store the evaluated value in the cache
          @cache[key] = values[key]
        end

        # Return the values for all keys, including cached ones
        keys.each_with_object({}) do |key, result|
          result[key] = @cache[key]
        end
      end
    end

    def explain(key)
      # Clear the cache for each new explanation to ensure fresh values
      @cache = {}
      explain_recursive(key)
    end

    private

    def explain_recursive(key, indent = 0)
      node = node_index[key]
      value = fetch(key)
      indent_str = "  " * indent

      return "#{indent_str}-> :#{key} is an input value: #{context[key].inspect}" unless node

      output = "#{indent_str}-> :#{key} evaluated to: #{value.inspect}\n"
      output += explain_expression(node.expression, indent + 1)
      output
    end

    def explain_expression(expr, indent)
      indent_str = "  " * indent

      case expr
      when Syntax::Expressions::CallExpression
        output = "#{indent_str}- is fn(:#{expr.fn_name}) with arguments:\n"
        expr.args.each { |arg| output += explain_expression(arg, indent + 1) }
        output
      when Syntax::TerminalExpressions::Binding
        "#{indent_str}- references rule:\n" + explain_recursive(expr.name, indent + 1)
      when Syntax::TerminalExpressions::Field
        "#{indent_str}- is key(:#{expr.name}) with value: #{context[expr.name].inspect}\n"
      when Syntax::TerminalExpressions::Literal
        "#{indent_str}- is literal value: #{expr.value.inspect}\n"
      when Syntax::Expressions::CascadeExpression
        output = "#{indent_str}- is a cascade expression:\n"
        triggered = false

        expr.cases.each do |case_node|
          condition_str, trait_keys = format_condition(case_node.condition)

          if triggered
            output += "#{indent_str}  - Rule '#{condition_str}' was skipped because a previous rule matched.\n"
            next
          end

          is_match = trait_keys.all? { |pk| fetch(pk) }

          if is_match
            output += "#{indent_str}  - Checking rule '#{condition_str}'... MATCHED\n"
            trait_keys.each do |pk|
              output += explain_recursive(pk, indent + 2)
            end
            triggered = true
          else
            output += "#{indent_str}  - Checking rule '#{condition_str}'... SKIPPED (condition was false)\n"
          end
        end
        output
      else
        "#{indent_str}- is an unknown expression type.\n"
      end
    end

    def format_condition(condition_node)
      case condition_node
      when Syntax::TerminalExpressions::Binding
        # Single trait: `on :rich`
        ["on :#{condition_node.name}", [condition_node.name]]
      when Syntax::Expressions::CallExpression
        # Multi-trait: `on :rich, :famous`
        keys = condition_node.args.first.elements.map(&:name)
        str = "on #{keys.map { |k| ":#{k}" }.join(' and ')}"
        [str, keys]
      when Syntax::TerminalExpressions::Literal
        # The 'base' case
        ["base", []]
      else
        ["unknown condition", []]
      end
    end
  end
end
