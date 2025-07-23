# frozen_string_literal: true

module Kumi
  module Explain
    class ExplanationGenerator
      def initialize(schema, analyzer_result, inputs)
        @schema = schema
        @analyzer_result = analyzer_result
        @inputs = inputs
        @definitions = analyzer_result.definitions
        @compiled_schema = Compiler.compile(schema, analyzer: analyzer_result)

        # Set up compiler once for expression evaluation
        @compiler = Compiler.new(schema, analyzer_result)
        @compiler.send(:build_index)

        # Populate bindings from the compiled schema
        @compiled_schema.bindings.each do |name, (type, fn)|
          @compiler.instance_variable_get(:@bindings)[name] = [type, fn]
        end
      end

      def explain(target_name)
        declaration = @definitions[target_name]
        raise ArgumentError, "Unknown declaration: #{target_name}" unless declaration

        expression = declaration.expression
        result_value = @compiled_schema.evaluate_binding(target_name, @inputs)
        
        prefix = "#{target_name} = "
        expression_str = format_expression(expression, indent_context: prefix.length)

        "#{prefix}#{expression_str} => #{format_value(result_value)}"
      end

      private

      def format_expression(expr, indent_context: 0)
        case expr
        when Syntax::TerminalExpressions::FieldRef
          "input.#{expr.name}"
        when Syntax::TerminalExpressions::Binding
          expr.name.to_s
        when Syntax::TerminalExpressions::Literal
          format_value(expr.value)
        when Syntax::Expressions::CallExpression
          format_call_expression(expr, indent_context: indent_context)
        when Syntax::Expressions::ListExpression
          "[#{expr.elements.map { |e| format_expression(e, indent_context: indent_context) }.join(', ')}]"
        when Syntax::Expressions::CascadeExpression
          format_cascade_expression(expr, indent_context: indent_context)
        else
          expr.class.name.split("::").last
        end
      end

      def format_call_expression(expr, indent_context: 0)
        args = expr.args.map do |arg|
          arg_desc = format_expression(arg, indent_context: indent_context)
          
          # For literals and literal lists, just show the value, no need for "100 = 100"
          if arg.is_a?(Syntax::TerminalExpressions::Literal) ||
             (arg.is_a?(Syntax::Expressions::ListExpression) && arg.elements.all?(Syntax::TerminalExpressions::Literal))
            arg_desc
          else
            arg_value = evaluate_expression(arg)
            "#{arg_desc} = #{format_value(arg_value)}"
          end
        end

        if args.length > 1
          # Align with opening parenthesis, accounting for the full context
          function_indent = indent_context + expr.fn_name.to_s.length + 1
          indent = " " * function_indent
          "#{expr.fn_name}(#{args.join(",\n#{indent}")})"
        else
          "#{expr.fn_name}(#{args.join(', ')})"
        end
      end

      def format_cascade_expression(expr, indent_context: 0)
        lines = []
        expr.cases.each do |case_expr|
          condition_result = evaluate_expression(case_expr.condition)
          condition_desc = format_expression(case_expr.condition, indent_context: indent_context)
          result_desc = format_expression(case_expr.result, indent_context: indent_context)

          status = condition_result ? "✓" : "✗"
          lines << "  #{status} on #{condition_desc}, #{result_desc}"

          break if condition_result
        end

        "\n#{lines.join("\n")}"
      end

      def format_value(value)
        case value
        when Float, Integer
          format_number(value)
        when String
          "\"#{value}\""
        when Array
          if value.length <= 4
            "[#{value.map { |v| format_value(v) }.join(', ')}]"
          else
            "[#{value.take(4).map { |v| format_value(v) }.join(', ')}, …]"
          end
        else
          value.to_s
        end
      end

      def format_number(num)
        return num.to_s unless num.is_a?(Numeric)

        if num.is_a?(Integer) || (num.is_a?(Float) && num == num.to_i)
          int_val = num.to_i
          if int_val.abs >= 1000
            int_val.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1 ').reverse
          else
            int_val.to_s
          end
        else
          num.to_s
        end
      end

      def evaluate_expression(expr)
        case expr
        when Syntax::TerminalExpressions::Binding
          @compiled_schema.evaluate_binding(expr.name, @inputs)
        when Syntax::TerminalExpressions::FieldRef
          @inputs[expr.name]
        when Syntax::TerminalExpressions::Literal
          expr.value
        else
          # For complex expressions, compile and evaluate using existing compiler
          compiled_fn = @compiler.send(:compile_expr, expr)
          compiled_fn.call(@inputs)
        end
      end
    end

    module_function

    def call(schema_class, target_name, inputs:)
      syntax_tree = schema_class.instance_variable_get(:@__syntax_tree__)
      analyzer_result = schema_class.instance_variable_get(:@__analyzer_result__)

      raise ArgumentError, "Schema not found or not compiled" unless syntax_tree && analyzer_result

      generator = ExplanationGenerator.new(syntax_tree, analyzer_result, inputs)
      generator.explain(target_name)
    end
  end
end
