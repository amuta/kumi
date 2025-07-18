# frozen_string_literal: true

require "ostruct"

module Kumi
  module Schema
    def from(context)
      raise("No schema defined") unless @__schema__

      Runner.new(context, @__schema__, @__analyzer_result__.definitions)
    end

    # The schema compilation logic remains the same
    def schema(&block)
      @__syntax_tree__ = Kumi::Parser::Dsl.build_syntax_tree(&block).freeze
      @__analyzer_result__ = Analyzer.analyze!(@__syntax_tree__).freeze
      @__schema__ = Compiler.compile(@__syntax_tree__, analyzer: @__analyzer_result__).freeze

      # Return an object that provides access to both the compiled schema and analysis
      OpenStruct.new(
        runner: Runner.new({}, @__schema__, @__analyzer_result__.definitions),
        analysis: @__analyzer_result__
      )
    end
  end
end
