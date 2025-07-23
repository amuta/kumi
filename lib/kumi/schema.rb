# frozen_string_literal: true

require "ostruct"

module Kumi
  module Schema
    Inspector = Struct.new(:syntax_tree, :analyzer_result, :compiled_schema) do
      def inspect
        "#<#{self.class} syntax_tree: #{syntax_tree.inspect}, analyzer_result: #{analyzer_result.inspect}, schema: #{schema.inspect}>"
      end
    end

    def from(context)
      raise("No schema defined") unless @__schema__

      # Validate input types and domain constraints
      input_meta = @__analyzer_result__.state[:input_meta] || {}
      violations = Input::Validator.validate_context(context, input_meta)

      raise Errors::InputValidationError, violations unless violations.empty?

      SchemaInstance.new(@__schema__, @__analyzer_result__.definitions, context)
    end

    # The schema compilation logic remains the same
    def schema(&block)
      @__syntax_tree__ = Kumi::Parser::Dsl.build_syntax_tree(&block).freeze
      @__analyzer_result__ = Analyzer.analyze!(@__syntax_tree__).freeze
      @__schema__ = Compiler.compile(@__syntax_tree__, analyzer: @__analyzer_result__).freeze

      Inspector.new(@__syntax_tree__, @__analyzer_result__, @__schema__)
    end
  end
end
