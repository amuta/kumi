# frozen_string_literal: true

module Kumi
  module Core
    # The Ruby DSL frontend. Parses an in-Ruby `schema do ... end` block into a
    # `Kumi::Syntax::Root` AST — the same AST the text (`.kumi`) frontend emits.
    #
    # Boundary: this module's only public entry point is `Dsl.build_syntax_tree`,
    # and it depends only on `Kumi::Syntax::*`, `Kumi::Core::Types`, and
    # `Kumi::Core::Errors`. Everything else (SchemaBuilder, ExpressionConverter,
    # the input/cascade builders, the proxies, the operator refinements in Sugar)
    # is internal. Keep it that way: the frontend should never reach into the
    # analyzer/IR, and callers should never reach past `Dsl`.
    module RubyParser
      module Dsl
        # Build a Syntax::Root from a Ruby DSL block. This is the single entry
        # point for the Ruby frontend.
        def self.build_syntax_tree(&)
          Parser.new.parse(&)
        end
      end
    end
  end
end
