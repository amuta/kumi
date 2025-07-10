# frozen_string_literal: true

module Kumi
  module Schema
    def from(context)
      raise("No schema defined") unless @__schema__

      Runner.new(context, @__schema__, @__analyzer_result__.definitions)
    end

    # The schema compilation logic remains the same
    def schema(&block)
      @__syntax_tree__ = Kumi::Parser::Dsl.build_sytax_tree(&block).freeze
      @__analyzer_result__ = Analyzer.analyze!(@__syntax_tree__).freeze
      @__schema__ = Compiler.compile(@__syntax_tree__, analyzer: @__analyzer_result__).freeze
    end
  end
end
