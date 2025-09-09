# frozen_string_literal: true

module Kumi
  module Core
    module Explain
      class ExplanationGenerator
        def initialize(syntax_tree, analysis_state, inputs, registry: Kumi::Registry)
          @syntax_tree = syntax_tree
          @state       = analysis_state
          @inputs      = inputs
          @definitions = analysis_state[:declarations] || {}
          @registry    = registry

          @program = Kumi::Runtime::Executable.from_analysis(@state, registry: nil)
          @session = @program.read(@inputs, mode: :ruby)
        end

        def explain(target_name)
          decl = @definitions[target_name] or raise ArgumentError, "Unknown declaration: #{target_name}"
          expr = decl.expression
          value = @session.get(target_name)

          prefix = "#{target_name} = "
          expr_str = format_expression(expr, indent_context: prefix.length)

          "#{prefix}#{expr_str} => #{format_value(value)}"
        end

        private

        # ---------- formatting ----------

        def format_expression(expr, indent_context: 0, nested: false)
          case expr
          when Kumi::Syntax::InputReference
            "input.#{expr.name}"
          when Kumi::Syntax::InputElementReference
            "input.#{expr.path.join('.')}"
          when Kumi::Syntax::DeclarationReference
            expr.name.to_s
          when Kumi::Syntax::Literal
            format_value(expr.value)
          when Kumi::Syntax::ArrayExpression
            "[" + expr.elements.map { |e| format_expression(e, indent_context:, nested:) }.join(", ") + "]"
          when Kumi::Syntax::CascadeExpression
            format_cascade(expr, indent_context:)
          when Kumi::Syntax::CallExpression
            format_call(expr, indent_context:, nested:)
          else
            expr.class.name.split("::").last
          end
        end

        def format_call(expr, indent_context:, nested:)
          fn = expr.fn_name
          if pretty_print?(fn)
            format_pretty(expr, fn, indent_context:, nested:)
          else
            format_generic(expr, indent_context:)
          end
        end

        def pretty_print?(fn)
          %i[add subtract multiply divide == != > < >= <= and or not].include?(fn)
        end

        def format_pretty(expr, fn, indent_context:, nested:)
          if needs_eval?(expr.args) && !nested
            if chain_of_same_op?(expr, fn)
              ops = flatten_chain(expr, fn)
              sym = op_symbol(fn)
              sym_args = ops.map { |a| format_expression(a, indent_context:, nested: true) }
              eval_args = ops.map { |a| eval_arg_for_display(a) }
              "#{sym_args.join(" #{sym} ")} = #{eval_args.join(" #{sym} ")}"
            else
              sym_args = expr.args.map { |a| format_expression(a, indent_context:, nested: true) }
              eval_args = expr.args.map { |a| eval_arg_for_display(a) }
              display_fmt(fn, sym_args) + " = " + display_fmt(fn, eval_args)
            end
          else
            display_fmt(fn, expr.args.map { |a| format_expression(a, indent_context:, nested: true) })
          end
        end

        def format_generic(expr, indent_context:)
          parts = expr.args.map do |a|
            desc = format_expression(a, indent_context:)
            if literalish?(a)
              desc
            else
              val = evaluate(a)
              "#{desc} = #{format_value(val)}"
            end
          end
          if parts.length > 1
            indent = " " * (indent_context + expr.fn_name.to_s.length + 1)
            "#{expr.fn_name}(#{parts.join(",\n#{indent}")})"
          else
            "#{expr.fn_name}(#{parts.join(', ')})"
          end
        end

        def format_cascade(expr, indent_context:)
          lines = []
          expr.cases.each do |c|
            cond_val = evaluate(c.condition)
            cond_desc = format_expression(c.condition, indent_context:)
            res_desc  = format_expression(c.result, indent_context:)
            lines << "  #{cond_val ? '✓' : '✗'} on #{cond_desc}, #{res_desc}"
            break if cond_val
          end
          "\n" + lines.join("\n")
        end

        def literalish?(expr)
          expr.is_a?(Kumi::Syntax::Literal) ||
            (expr.is_a?(Kumi::Syntax::ArrayExpression) && expr.elements.all?(Kumi::Syntax::Literal))
        end

        def needs_eval?(args)
          args.any? { |a| !literalish?(a) }
        end

        def chain_of_same_op?(expr, fn) = expr.args.any? { |a| a.is_a?(Kumi::Syntax::CallExpression) && a.fn_name == fn }

        def flatten_chain(expr, fn)
          expr.args.flat_map do |a|
            a.is_a?(Kumi::Syntax::CallExpression) && a.fn_name == fn ? flatten_chain(a, fn) : [a]
          end
        end

        def op_symbol(fn)
          { add: "+", subtract: "-", multiply: "×", divide: "÷" }[fn] || fn.to_s
        end

        def display_fmt(fn, args)
          case fn
          when :add      then args.join(" + ")
          when :subtract then args.join(" - ")
          when :multiply then args.join(" × ")
          when :divide   then args.join(" ÷ ")
          when :==       then "#{args[0]} == #{args[1]}"
          when :!=       then "#{args[0]} != #{args[1]}"
          when :>        then "#{args[0]} > #{args[1]}"
          when :<        then "#{args[0]} < #{args[1]}"
          when :>=       then "#{args[0]} >= #{args[1]}"
          when :<=       then "#{args[0]} <= #{args[1]}"
          when :and      then args.join(" && ")
          when :or       then args.join(" || ")
          when :not      then "!#{args[0]}"
          else                "#{fn}(#{args.join(', ')})"
          end
        end

        def eval_arg_for_display(arg)
          return format_expression(arg, indent_context: 0, nested: true) if literalish?(arg)

          val = evaluate(arg)
          if arg.is_a?(Kumi::Syntax::DeclarationReference)
            "(#{format_expression(arg, indent_context: 0, nested: true)} = #{format_value(val)})"
          else
            format_value(val)
          end
        end

        def format_value(v)
          case v
          when Float, Integer then format_number(v)
          when String         then "\"#{v}\""
          when Array          then if v.length <= 4
                                     "[#{v.map { |x| format_value(x) }.join(', ')}]"
                                   else
                                     "[#{v.take(4).map { |x| format_value(x) }.join(', ')}, …]"
                                   end
          else v.to_s
          end
        end

        def format_number(n)
          return n.to_s unless n.is_a?(Numeric)

          i = n.is_a?(Integer) || n == n.to_i ? n.to_i : nil
          return n.to_s unless i

          i.abs >= 1000 ? i.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1 ').reverse : i.to_s
        end

        # ---------- evaluation (Program + Registry) ----------

        def evaluate(expr)
          case expr
          when Kumi::Syntax::DeclarationReference
            @session.get(expr.name)
          when Kumi::Syntax::InputReference
            fetch_indifferent(@inputs, expr.name)
          when Kumi::Syntax::InputElementReference
            dig_path(@inputs, expr.path)
          when Kumi::Syntax::Literal
            expr.value
          when Kumi::Syntax::ArrayExpression
            expr.elements.map { |e| evaluate(e) }
          when Kumi::Syntax::CascadeExpression
            evaluate_cascade(expr)
          when Kumi::Syntax::CallExpression
            eval_call(expr)
          else
            raise "Unsupported expression: #{expr.class}"
          end
        end

        def eval_call(expr)
          entry = @registry.entry(expr.fn_name) or raise "Unknown function: #{expr.fn_name}"
          fn = entry.fn
          args = expr.args.map { |a| evaluate(a) }
          fn.call(*args)
        end

        def evaluate_cascade(expr)
          expr.cases.each do |c|
            return evaluate(c.result) if evaluate(c.condition)
          end
          nil
        end

        def fetch_indifferent(h, k)
          h[k] || h[k.to_s] || h[k.to_sym]
        end

        def dig_path(h, path)
          node = h
          path.each do |seg|
            node = if node.is_a?(Hash)
                     fetch_indifferent(node, seg)
                   else
                     # if arrays are in path, interpret seg as index when Integer-like
                     seg.is_a?(Integer) ? node[seg] : nil
                   end
          end
          node
        end
      end

      module_function

      def call(schema_class, target_name, inputs:)
        syntax_tree     = schema_class.instance_variable_get(:@__syntax_tree__)
        analysis_state  = schema_class.instance_variable_get(:@__analyzer_result__)&.state
        raise ArgumentError, "Schema not found or not compiled" unless syntax_tree && analysis_state

        ExplanationGenerator.new(syntax_tree, analysis_state, inputs).explain(target_name)
      end
    end
  end
end
