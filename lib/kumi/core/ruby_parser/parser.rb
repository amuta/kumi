# frozen_string_literal: true

module Kumi
  module Core
    module RubyParser
      # Main parser class for Ruby DSL
      class Parser
        include Syntax
        include ErrorReporting

        def initialize
          @context = BuildContext.new
          @interface = SchemaBuilder.new(@context)
        end

        def parse(&rule_block)
          enable_refinements(rule_block)

          before_consts = ::Object.constants
          @interface.freeze # stop singleton hacks
          @interface.instance_eval(&rule_block)
          added = ::Object.constants - before_consts

          unless added.empty?
            raise Kumi::Core::Errors::SemanticError,
                  "DSL cannot define global constants: #{added.join(', ')}"
          end

          build_syntax_tree
        rescue ArgumentError => e
          handle_parse_error(e)
          raise
        end

        private

        def enable_refinements(rule_block)
          rule_block.binding.eval("using Kumi::Core::RubyParser::Sugar::ExpressionRefinement")
          rule_block.binding.eval("using Kumi::Core::RubyParser::Sugar::NumericRefinement")
          rule_block.binding.eval("using Kumi::Core::RubyParser::Sugar::StringRefinement")
          rule_block.binding.eval("using Kumi::Core::RubyParser::Sugar::ArrayRefinement")
          rule_block.binding.eval("using Kumi::Core::RubyParser::Sugar::ModuleRefinement")
        rescue RuntimeError, NoMethodError
          # Refinements disabled in method scope - continue without them
        end

        def build_syntax_tree
          Root.new(@context.inputs, @context.attributes, @context.traits)
        end

        def handle_parse_error(error)
          return unless literal_comparison_error?(error)

          warn <<~HINT
            #{error.backtrace.first.split(':', 2).join(':')}: \
            Literal‑left comparison failed because the schema block is \
            defined inside a method (Ruby disallows refinements there).

            • Move the `schema do … end` block to the top level of a class or module, OR
            • Write the comparison as `input.age >= 80` (preferred), OR
            • Wrap the literal: `lit(80) <= input.age`.
          HINT
        end

        def literal_comparison_error?(error)
          error.message =~ /comparison of Integer with Kumi::Syntax::/i
        end
      end
    end
  end
end
