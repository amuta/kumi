# frozen_string_literal: true

module Kumi
  module Parser
    module Dsl
      #
      # Build the syntax tree for a rule‑block.
      # ‑ Literal‑left comparisons (`80 <= input.age`) work automatically
      #   when the block is defined at top level or inside a class / module
      #   body.  If the block is **inside a method**, Ruby forbids `using`
      #   refinements, so we fall back and print a hint.
      #
      def self.build_syntax_tree(&rule_block)
        context = DslBuilderContext.new
        proxy   = DslProxy.new(context)

        # ------------------------------------------------------------------
        # 1) Attempt to activate refinements unconditionally; Ruby will raise
        #    RuntimeError ("Module#using is not permitted in methods")
        #    when the block’s lexical scope is a method.
        # ------------------------------------------------------------------
        refinement_enabled = false
        begin
          rule_block.binding.eval("using Kumi::Parser::Sugar::ExpressionRefinement")
          rule_block.binding.eval("using Kumi::Parser::Sugar::NumericRefinement")
          rule_block.binding.eval("using Kumi::Parser::Sugar::StringRefinement")
          refinement_enabled = true
        rescue RuntimeError, NoMethodError
          # method scope: refinements can't be injected; proceed without them
        end

        # ------------------------------------------------------------------
        # 2) Evaluate the rule‑block inside the proxy DSL context
        # ------------------------------------------------------------------
        begin
          proxy.instance_eval(&rule_block)
        rescue ArgumentError => e
          # Detect the specific failure pattern: literal‑left comparison
          # between Integer and a Kumi expression *when* refinements were off.
          if !refinement_enabled &&
             e.message =~ /comparison of Integer with Kumi::Syntax::/i

            warn <<~HINT
              #{e.backtrace.first.split(':', 2).join(':')}: \
              Literal‑left comparison failed because the schema block is \
              defined INSIDE a method (Ruby disallows refinements there).

              • Move the `schema do … end` block to the top level of a class \
                or module, OR
              • Write the comparison as `input.age >= 80` (preferred), OR
              • Wrap the literal: `lit(80) <= input.age`.
            HINT
          end
          raise # re‑raise the original ArgumentError (keeps caret trace)
        end

        # ------------------------------------------------------------------
        Syntax::Root.new(
          context.inputs,
          context.attributes,
          context.traits
        )
      end
    end
  end
end
