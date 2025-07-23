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

      def format_expression(expr, indent_context: 0, nested: false)
        case expr
        when Syntax::TerminalExpressions::FieldRef
          "input.#{expr.name}"
        when Syntax::TerminalExpressions::Binding
          expr.name.to_s
        when Syntax::TerminalExpressions::Literal
          format_value(expr.value)
        when Syntax::Expressions::CallExpression
          format_call_expression(expr, indent_context: indent_context, nested: nested)
        when Syntax::Expressions::ListExpression
          "[#{expr.elements.map { |e| format_expression(e, indent_context: indent_context, nested: nested) }.join(', ')}]"
        when Syntax::Expressions::CascadeExpression
          format_cascade_expression(expr, indent_context: indent_context)
        else
          expr.class.name.split("::").last
        end
      end

      def format_call_expression(expr, indent_context: 0, nested: false)
        if pretty_printable?(expr.fn_name)
          format_pretty_function(expr, expr.fn_name, indent_context, nested)
        else
          format_generic_function(expr, indent_context)
        end
      end

      def format_pretty_function(expr, fn_name, _indent_context, nested = false)
        if needs_evaluation?(expr.args) && !nested
          # For top-level expressions, show the flattened symbolic form and evaluation
          if is_chain_of_same_operator?(expr, fn_name)
            # For chains like a + b + c, flatten to show all operands
            all_operands = flatten_operator_chain(expr, fn_name)
            symbolic_operands = all_operands.map { |op| format_expression(op, indent_context: 0, nested: true) }
            symbolic_format = symbolic_operands.join(" #{get_operator_symbol(fn_name)} ")

            evaluated_operands = all_operands.map do |op|
              if op.is_a?(Syntax::TerminalExpressions::Literal)
                format_expression(op, indent_context: 0, nested: true)
              else
                arg_value = format_value(evaluate_expression(op))
                if op.is_a?(Syntax::TerminalExpressions::Binding) && all_operands.length > 1
                  "(#{format_expression(op, indent_context: 0, nested: true)} = #{arg_value})"
                else
                  arg_value
                end
              end
            end
            evaluated_format = evaluated_operands.join(" #{get_operator_symbol(fn_name)} ")

            "#{symbolic_format} = #{evaluated_format}"
          else
            # Regular pretty formatting for non-chain expressions
            symbolic_args = expr.args.map { |arg| format_expression(arg, indent_context: 0, nested: true) }
            symbolic_format = get_display_format(fn_name, symbolic_args)

            evaluated_args = expr.args.map do |arg|
              if arg.is_a?(Syntax::TerminalExpressions::Literal)
                format_expression(arg, indent_context: 0, nested: true)
              else
                arg_value = format_value(evaluate_expression(arg))
                if arg.is_a?(Syntax::TerminalExpressions::Binding) &&
                   expr.args.count { |a| !a.is_a?(Syntax::TerminalExpressions::Literal) } > 1
                  "(#{format_expression(arg, indent_context: 0, nested: true)} = #{arg_value})"
                else
                  arg_value
                end
              end
            end
            evaluated_format = get_display_format(fn_name, evaluated_args)

            "#{symbolic_format} = #{evaluated_format}"
          end
        else
          # For nested expressions, just show the symbolic form without evaluation details
          args = expr.args.map { |arg| format_expression(arg, indent_context: 0, nested: true) }
          get_display_format(fn_name, args)
        end
      end

      def is_chain_of_same_operator?(expr, fn_name)
        return false unless %i[add subtract multiply divide].include?(fn_name)

        # Check if any argument is the same operator
        expr.args.any? do |arg|
          arg.is_a?(Syntax::Expressions::CallExpression) && arg.fn_name == fn_name
        end
      end

      def flatten_operator_chain(expr, operator)
        operands = []

        expr.args.each do |arg|
          if arg.is_a?(Syntax::Expressions::CallExpression) && arg.fn_name == operator
            # Recursively flatten nested operations of the same type
            operands.concat(flatten_operator_chain(arg, operator))
          else
            operands << arg
          end
        end

        operands
      end

      def get_operator_symbol(fn_name)
        case fn_name
        when :add then "+"
        when :subtract then "-"
        when :multiply then "×"
        when :divide then "÷"
        else fn_name.to_s
        end
      end

      def pretty_printable?(fn_name)
        %i[add subtract multiply divide == != > < >= <= and or not].include?(fn_name)
      end

      def get_display_format(fn_name, args)
        case fn_name
        when :add then args.join(" + ")
        when :subtract then args.join(" - ")
        when :multiply then args.join(" × ")
        when :divide then args.join(" ÷ ")
        when :== then "#{args[0]} == #{args[1]}"
        when :!= then "#{args[0]} != #{args[1]}"
        when :> then "#{args[0]} > #{args[1]}"
        when :< then "#{args[0]} < #{args[1]}"
        when :>= then "#{args[0]} >= #{args[1]}"
        when :<= then "#{args[0]} <= #{args[1]}"
        when :and then args.join(" && ")
        when :or then args.join(" || ")
        when :not then "!#{args[0]}"
        else "#{fn_name}(#{args.join(', ')})"
        end
      end

      def format_generic_function(expr, indent_context)
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

      def needs_evaluation?(args)
        args.any? do |arg|
          !arg.is_a?(Syntax::TerminalExpressions::Literal) &&
            !(arg.is_a?(Syntax::Expressions::ListExpression) && arg.elements.all?(Syntax::TerminalExpressions::Literal))
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
