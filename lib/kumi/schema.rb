# frozen_string_literal: true

require "ostruct"

module Kumi
  module Schema
    attr_reader :__syntax_tree__, :__analyzer_result__, :__compiled_schema__

    Inspector = Struct.new(:syntax_tree, :analyzer_result, :compiled_schema) do
      def inspect
        "#<#{self.class} syntax_tree: #{syntax_tree.inspect}, analyzer_result: #{analyzer_result.inspect}, schema: #{schema.inspect}>"
      end
    end

    def from(context)
      raise("No schema defined") unless @__compiled_schema__

      # Validate input types and domain constraints
      input_meta = @__analyzer_result__.state[:inputs] || {}
      violations = Core::Input::Validator.validate_context(context, input_meta)

      raise Errors::InputValidationError, violations unless violations.empty?

      Core::SchemaInstance.new(@__compiled_schema__, @__analyzer_result__.state, context)
    end

    def explain(context, *keys)
      raise("No schema defined") unless @__compiled_schema__

      # Validate input types and domain constraints
      input_meta = @__analyzer_result__.state[:inputs] || {}
      violations = Core::Input::Validator.validate_context(context, input_meta)

      raise Errors::InputValidationError, violations unless violations.empty?

      keys.each do |key|
        puts Core::Explain.call(self, key, inputs: context)
      end

      nil
    end

    def schema(&block)
      @__syntax_tree__ = Core::RubyParser::Dsl.build_syntax_tree(&block).freeze
      @__analyzer_result__ = Analyzer.analyze!(@__syntax_tree__).freeze
      @__compiled_schema__ = Compiler.compile(@__syntax_tree__, analyzer: @__analyzer_result__).freeze

      Inspector.new(@__syntax_tree__, @__analyzer_result__, @__compiled_schema__)
    end

    def schema_metadata
      raise("No schema defined") unless @__analyzer_result__

      @schema_metadata ||= SchemaMetadata.new(@__analyzer_result__.state, @__syntax_tree__)
    end
  end
end
