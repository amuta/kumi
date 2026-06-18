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
        rescue ArgumentError, NoMethodError => e
          raise translate_literal_comparison(e) || e
        end

        private

        def enable_refinements(rule_block)
          rule_block.binding.eval("using Kumi::Core::RubyParser::Sugar::ExpressionRefinement")
          rule_block.binding.eval("using Kumi::Core::RubyParser::Sugar::NumericRefinement")
          rule_block.binding.eval("using Kumi::Core::RubyParser::Sugar::StringRefinement")
          rule_block.binding.eval("using Kumi::Core::RubyParser::Sugar::ArrayRefinement")
        rescue RuntimeError, NoMethodError
          # Refinements disabled in method scope - continue without them
        end

        def build_syntax_tree
          Root.new(@context.inputs, @context.values, @context.traits, @context.imports, hints: @context.root_hints)
        end

        # A literal-on-the-left operator (`80 <= input.age`, `1 + input.x`) fails
        # when the schema block is defined inside a method, where Ruby disallows
        # the numeric refinement that would otherwise lift the literal. Without the
        # refinement, `Integer#<=`/`#+` try to coerce the DSL proxy and Ruby raises
        # a `coerce`/`comparison of Integer with ...` error. Turn it into a
        # first-class, located hint instead of leaking the raw Ruby error.
        def method_scope_refinement_failure?(error)
          msg = error.message
          msg.match?(/comparison of Integer with Kumi::Syntax::/i) ||
            (msg.include?("coerce") && msg.include?("RubyParser"))
        end

        def translate_literal_comparison(error)
          return nil unless method_scope_refinement_failure?(error)

          frame = error.backtrace_locations&.find { |f| !f.path.to_s.include?("ruby_parser") }
          location = frame && Location.new(file: frame.path, line: frame.lineno, column: 0)

          Kumi::Core::Errors::SyntaxError.new(
            "a literal-on-the-left expression (e.g. `80 <= input.age`) failed " \
            "because the schema block is defined inside a method, where Ruby " \
            "disallows the numeric refinement that lifts the literal. Move the " \
            "`schema do ... end` block to the top level of a class or module, or " \
            "put the literal on the right: `input.age >= 80`.",
            location
          )
        end
      end
    end
  end
end
