# frozen_string_literal: true

require "set"

module Kumi
  # Main interface for schema metadata extraction
  class SchemaMetadata
    attr_reader :inputs, :values, :traits, :functions

    def initialize(analyzed_schema, syntax_tree)
      @analyzed_schema = analyzed_schema
      @syntax_tree = syntax_tree
      @inputs = extract_inputs
      @values = extract_values
      @traits = extract_traits
      @functions = extract_functions
    end

    def to_h
      {
        inputs: @inputs,
        values: @values,
        traits: @traits,
        functions: @functions
      }
    end

    def to_json(*args)
      to_h.to_json(*args)
    end

    def to_json_schema
      JsonSchema::Generator.new(self).generate
    end

    private

    def extract_inputs
      return {} unless @analyzed_schema.state[:input_meta]

      @analyzed_schema.state[:input_meta].transform_values do |field_info|
        {
          type: normalize_type(field_info[:type]),
          domain: normalize_domain(field_info[:domain]),
          required: true
        }.compact
      end
    end

    def extract_values
      return {} unless @analyzed_schema.state[:dependency_graph]

      value_nodes = (@syntax_tree.values || []).flatten.select { |node| node.is_a?(Syntax::ValueDeclaration) }
      dependency_graph = @analyzed_schema.state[:dependency_graph] || {}
      inferred_types = @analyzed_schema.state[:decl_types] || {}

      value_nodes.each_with_object({}) do |node, result|
        name = node.name
        dependency_edges = dependency_graph[name] || []
        dependencies = dependency_edges.map(&:to)

        result[name] = {
          type: inferred_types[name],
          dependencies: dependencies,
          computed: true
        }.tap do |spec|
          if node.expression.is_a?(Syntax::CascadeExpression)
            spec[:cascade] = extract_cascade_info(node.expression)
          else
            spec[:expression] = expression_to_string(node.expression)
          end
        end.compact
      end
    end

    def extract_traits
      return {} unless @analyzed_schema.state[:dependency_graph]

      trait_nodes = (@syntax_tree.traits || []).flatten.select { |node| node.is_a?(Syntax::TraitDeclaration) }
      dependency_graph = @analyzed_schema.state[:dependency_graph] || {}

      trait_nodes.each_with_object({}) do |node, result|
        name = node.name
        dependency_edges = dependency_graph[name] || []
        dependencies = dependency_edges.map(&:to)

        result[name] = {
          type: :boolean,
          dependencies: dependencies,
          condition: expression_to_string(node.expression)
        }.compact
      end
    end

    def extract_functions
      function_calls = Set.new

      value_nodes = (@syntax_tree.values || []).flatten.select { |node| node.is_a?(Syntax::ValueDeclaration) }
      trait_nodes = (@syntax_tree.traits || []).flatten.select { |node| node.is_a?(Syntax::TraitDeclaration) }

      value_nodes.each do |node|
        collect_function_calls(node.expression, function_calls)
      end

      trait_nodes.each do |node|
        collect_function_calls(node.expression, function_calls)
      end

      function_calls.each_with_object({}) do |func_name, result|
        next unless Kumi::FunctionRegistry.supported?(func_name)

        function_info = Kumi::FunctionRegistry.signature(func_name)
        result[func_name] = {
          param_types: function_info[:param_types],
          return_type: function_info[:return_type],
          arity: function_info[:arity],
          description: function_info[:description]
        }.compact
      end
    end

    def normalize_type(type_spec)
      case type_spec
      when Hash
        if type_spec.key?(:hash)
          :hash
        elsif type_spec.key?(:array)
          :array
        else
          type_spec
        end
      else
        type_spec
      end
    end

    def normalize_domain(domain_spec)
      case domain_spec
      when Range
        {
          type: :range,
          min: domain_spec.begin,
          max: domain_spec.end,
          exclusive_end: domain_spec.exclude_end?
        }
      when Array
        { type: :enum, values: domain_spec }
      when Proc
        { type: :custom, description: "custom validation function" }
      when Hash
        domain_spec
      end
    end

    def extract_cascade_info(cascade_expr)
      cases = cascade_expr.cases || []

      conditions = []
      base_case = nil

      cases.each do |case_expr|
        if case_expr.condition
          conditions << {
            when: [expression_to_string(case_expr.condition)],
            then: literal_value(case_expr.result)
          }
        else
          base_case = literal_value(case_expr.result)
        end
      end

      result = { conditions: conditions }
      result[:base] = base_case if base_case
      result
    end

    def expression_to_string(expr)
      case expr
      when Syntax::Literal
        expr.value.inspect
      when Syntax::InputReference
        "input.#{expr.name}"
      when Syntax::DeclarationReference
        expr.name.to_s
      when Syntax::CallExpression
        args = expr.args.map { |arg| expression_to_string(arg) }.join(", ")
        "#{expr.fn_name}(#{args})"
      else
        expr.class.name
      end
    end

    def literal_value(expr)
      expr.is_a?(Syntax::Literal) ? expr.value : expression_to_string(expr)
    end

    def collect_function_calls(expr, function_calls)
      case expr
      when Syntax::CallExpression
        function_calls << expr.fn_name
        expr.args.each { |arg| collect_function_calls(arg, function_calls) }
      when Syntax::CascadeExpression
        expr.cases.each do |case_expr|
          collect_function_calls(case_expr.condition, function_calls) if case_expr.condition
          collect_function_calls(case_expr.result, function_calls)
        end
      when Syntax::ArrayExpression
        expr.elements.each { |elem| collect_function_calls(elem, function_calls) }
      when Syntax::HashExpression
        expr.pairs.each do |pair|
          collect_function_calls(pair.key, function_calls)
          collect_function_calls(pair.value, function_calls)
        end
      end
    end
  end
end
