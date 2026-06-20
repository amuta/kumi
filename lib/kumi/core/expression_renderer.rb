# frozen_string_literal: true

module Kumi
  module Core
    # Renders a Syntax AST expression back into compact, readable algebra —
    # the form a human (or an LLM) reads to understand what a declaration
    # computes, without the source file. Deterministic and total over the node
    # set; an unknown node degrades to its class name rather than raising.
    #
    #   adult      := input.age >= 18
    #   line       := input.items[].item.qty * input.items[].item.price
    #   subtotal   := sum(line)
    #   tier       := cascade { (adult & wealthy) => "premium";
    #                           adult => "standard"; else => "none" }
    class ExpressionRenderer
      # Inverse of the parser's operator sugar, so `:multiply` prints as `*`.
      INFIX = {
        add: "+", subtract: "-", multiply: "*", divide: "/",
        modulo: "%", power: "**",
        "<": "<", "<=": "<=", ">": ">", ">=": ">=",
        "==": "==", "!=": "!=", and: "&", or: "|"
      }.freeze

      def self.render(node)
        new.render(node)
      end

      def render(node)
        case node
        when Kumi::Syntax::Literal              then render_literal(node.value)
        when Kumi::Syntax::InputReference       then "input.#{node.name}"
        when Kumi::Syntax::InputElementReference then render_input_element(node.path)
        when Kumi::Syntax::DeclarationReference  then node.name.to_s
        when Kumi::Syntax::CallExpression        then render_call(node)
        when Kumi::Syntax::CascadeExpression     then render_cascade(node)
        when Kumi::Syntax::ArrayExpression       then "[#{node.elements.map { |e| render(e) }.join(', ')}]"
        when Kumi::Syntax::HashExpression        then render_hash(node)
        else
          node.class.name&.split("::")&.last || node.inspect
        end
      end

      private

      def render_literal(value)
        case value
        when String then value.inspect
        when nil then "nil"
        else value.to_s
        end
      end

      # Render a nested input reference faithfully — the full declared path. We
      # do NOT strip element-selector keys here: the renderer has no axis
      # information, and a positional heuristic silently drops real array levels
      # for selector-less paths (`input.x.y.v` -> `input.x.v`). Cosmetic
      # shortening is the Printer's job, where axis data makes it lossless.
      def render_input_element(path)
        "input.#{path.join('.')}"
      end

      def render_call(node)
        fn = node.fn_name
        args = node.args || []

        if INFIX.key?(fn) && args.length == 2
          "(#{render(args[0])} #{INFIX[fn]} #{render(args[1])})"
        elsif fn == :cascade_and
          args.map { |a| render(a) }.join(" & ")
        else
          "#{fn}(#{args.map { |a| render(a) }.join(', ')})"
        end
      end

      def render_cascade(node)
        cases = node.cases.map do |c|
          cond = c.condition
          if cond.is_a?(Kumi::Syntax::Literal) && cond.value == true
            "else => #{render(c.result)}"
          else
            "when #{render(cond)} => #{render(c.result)}"
          end
        end
        # Inline when short; otherwise one case per line, indented.
        oneline = "cascade { #{cases.join('; ')} }"
        return oneline if oneline.length <= 80

        "cascade\n#{cases.map { |c| "          #{c}" }.join("\n")}"
      end

      def render_hash(node)
        pairs = node.pairs.map { |k, v| "#{render(k)}: #{render(v)}" }
        "{ #{pairs.join(', ')} }"
      end
    end
  end
end
