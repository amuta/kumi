# frozen_string_literal: true

require "ostruct"

module Kumi
  module Schema
    attr_reader :__syntax_tree__, :__analyzer_result__, :__executable__

    def from(context)
      # VERY IMPORTANT: This method is overriden on specs in order to use dual mode.

      raise("No schema defined") unless @__executable__

      # Validate input types and domain constraints
      input_meta = @__analyzer_result__.state[:input_metadata] || {}
      violations = Core::Input::Validator.validate_context(context, input_meta)

      raise Errors::InputValidationError, violations unless violations.empty?

      @__executable__.read(context, mode: :ruby)
    end

    def explain(context, *keys)
      raise("No schema defined") unless @__executable__

      # Validate input types and domain constraints
      input_meta = @__analyzer_result__.state[:input_metadata] || {}
      violations = Core::Input::Validator.validate_context(context, input_meta)

      raise Errors::InputValidationError, violations unless violations.empty?

      keys.each do |key|
        puts Core::Explain.call(self, key, inputs: context)
      end

      nil
    end

    def build_syntax_tree(&)
      @__syntax_tree__ = Core::RubyParser::Dsl.build_syntax_tree(&).freeze
    end

    def schema(&)
      # from_location = caller_locations(1, 1).first
      # raise "Called from #{from_location.path}:#{from_location.lineno}"
      @__syntax_tree__ = Dev::Profiler.phase("frontend.parse") do
        Core::RubyParser::Dsl.build_syntax_tree(&).freeze
      end

      puts Support::SExpressionPrinter.print(@__syntax_tree__, indent: 2) if ENV["KUMI_DEBUG"] || ENV["KUMI_PRINT_SYNTAX_TREE"]

      @__analyzer_result__ = Dev::Profiler.phase("analyzer") do
        Analyzer.analyze!(@__syntax_tree__).freeze
      end
      @__executable__ = Dev::Profiler.phase("compiler") do
        Compiler.compile(@__syntax_tree__, analyzer: @__analyzer_result__, schema_name: self.name).freeze
      end

      nil
    end

    def schema_metadata
      raise("No schema defined") unless @__analyzer_result__

      @schema_metadata ||= SchemaMetadata.new(@__analyzer_result__.state, @__syntax_tree__)
    end
  end
end
