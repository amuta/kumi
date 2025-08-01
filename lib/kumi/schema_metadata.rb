# frozen_string_literal: true

module Kumi
  # Primary interface for extracting structured metadata from analyzed Kumi schemas.
  #
  # SchemaMetadata provides both processed semantic metadata (inputs, values, traits, functions)
  # and raw analyzer state for advanced use cases. This interface is designed for building
  # external tools like form generators, documentation systems, and schema analysis utilities.
  #
  # @example Basic usage
  #   class MySchema
  #     extend Kumi::Schema
  #     schema do
  #       input do
  #         integer :age, domain: 18..65
  #         string :name
  #       end
  #       trait :adult, (input.age >= 18)
  #       value :greeting, "Hello " + input.name
  #     end
  #   end
  #
  #   metadata = MySchema.schema_metadata
  #   puts metadata.inputs[:age][:domain]  # => { type: :range, min: 18, max: 65, ... }
  #   puts metadata.traits[:adult][:condition]  # => ">=(input.age, 18)"
  #
  # @example Tool integration
  #   def generate_form_fields(schema_class)
  #     metadata = schema_class.schema_metadata
  #     metadata.inputs.map do |field_name, field_info|
  #       create_input_field(field_name, field_info[:type], field_info[:domain])
  #     end
  #   end
  class SchemaMetadata
    # @param state_hash [Hash] Raw analyzer state from multi-pass analysis
    # @param syntax_tree [Syntax::Root] Parsed AST of the schema definition
    def initialize(state_hash, syntax_tree)
      @state = state_hash
      @syntax_tree = syntax_tree
    end

    # Returns processed input field metadata with normalized types and domains.
    #
    # Transforms raw input metadata from the analyzer into a clean, tool-friendly format
    # with consistent type representation and domain constraint normalization.
    #
    # @return [Hash<Symbol, Hash>] Input field metadata keyed by field name
    # @example
    #   metadata.inputs
    #   # => {
    #   #   :age => { type: :integer, domain: { type: :range, min: 18, max: 65 }, required: true },
    #   #   :name => { type: :string, required: true },
    #   #   :items => { type: :array, required: true }
    #   # }
    def inputs
      @inputs ||= extract_inputs
    end

    # Returns processed value declaration metadata with dependencies and expressions.
    #
    # Extracts computed value information including type inference results, dependency
    # relationships, and expression representations. Cascade expressions are expanded
    # into structured condition/result pairs.
    #
    # @return [Hash<Symbol, Hash>] Value metadata keyed by declaration name
    # @example
    #   metadata.values
    #   # => {
    #   #   :tax_amount => {
    #   #     type: :float,
    #   #     dependencies: [:income, :tax_rate],
    #   #     computed: true,
    #   #     expression: "multiply(input.income, tax_rate)"
    #   #   },
    #   #   :status => {
    #   #     type: :string,
    #   #     dependencies: [:adult, :verified],
    #   #     computed: true,
    #   #     cascade: { conditions: [...], base: "default" }
    #   #   }
    #   # }
    def values
      @values ||= extract_values
    end

    # Returns processed trait metadata with conditions and dependencies.
    #
    # Extracts boolean trait information including dependency relationships and
    # human-readable condition expressions for documentation and analysis.
    #
    # @return [Hash<Symbol, Hash>] Trait metadata keyed by trait name
    # @example
    #   metadata.traits
    #   # => {
    #   #   :adult => {
    #   #     type: :boolean,
    #   #     dependencies: [:age],
    #   #     condition: ">=(input.age, 18)"
    #   #   },
    #   #   :eligible => {
    #   #     type: :boolean,
    #   #     dependencies: [:adult, :verified, :score],
    #   #     condition: "and(adult, verified, >(input.score, 80))"
    #   #   }
    #   # }
    def traits
      @traits ||= extract_traits
    end

    # Returns function registry information for functions used in the schema.
    #
    # Analyzes all expressions in the schema to identify function calls and extracts
    # their signatures from the function registry. Useful for documentation generation
    # and validation tooling.
    #
    # @return [Hash<Symbol, Hash>] Function metadata keyed by function name
    # @example
    #   metadata.functions
    #   # => {
    #   #   :multiply => {
    #   #     param_types: [:float, :float],
    #   #     return_type: :float,
    #   #     arity: 2,
    #   #     description: "Multiplies two numbers"
    #   #   },
    #   #   :sum => {
    #   #     param_types: [{ array: :float }],
    #   #     return_type: :float,
    #   #     arity: 1,
    #   #     description: "Sums array elements"
    #   #   }
    #   # }
    def functions
      @functions ||= extract_functions
    end

    # Returns serializable processed metadata as a hash.
    #
    # Combines all processed metadata (inputs, values, traits, functions) into a single
    # hash suitable for JSON serialization, API responses, and external tool integration.
    # Does not include raw AST nodes or analyzer state.
    #
    # @return [Hash<Symbol, Hash>] Serializable metadata hash
    # @example
    #   metadata.to_h
    #   # => {
    #   #   inputs: { :age => { type: :integer, ... }, ... },
    #   #   values: { :tax_amount => { type: :float, ... }, ... },
    #   #   traits: { :adult => { type: :boolean, ... }, ... },
    #   #   functions: { :multiply => { param_types: [...], ... }, ... }
    #   # }
    def to_h
      {
        inputs: inputs,
        values: values,
        traits: traits,
        functions: functions
      }
    end

    alias to_hash to_h

    # Returns raw analyzer state including AST nodes.
    #
    # Provides access to the complete analyzer state hash for advanced use cases
    # requiring direct AST manipulation or detailed analysis. Contains non-serializable
    # AST node objects and should not be used for JSON export.
    #
    # @return [Hash] Complete analyzer state with all keys and AST nodes
    # @example
    #   raw_state = metadata.analyzer_state
    #   declarations = raw_state[:declarations]  # AST nodes
    #   dependency_graph = raw_state[:dependencies]  # Edge objects
    def analyzer_state
      @state.dup
    end

    # @deprecated Use to_h instead for processed metadata
    def state
      @state
    end

    # Returns JSON representation of processed metadata.
    #
    # Serializes the processed metadata (inputs, values, traits, functions) to JSON.
    # Excludes raw analyzer state and AST nodes for clean serialization.
    #
    # @param args [Array] Arguments passed to Hash#to_json
    # @return [String] JSON representation
    def to_json(*args)
      require "json"
      to_h.to_json(*args)
    end

    # Returns JSON Schema representation of input fields.
    #
    # Generates a JSON Schema document describing the expected input structure,
    # including type constraints, domain validation, and Kumi-specific extensions
    # for computed values and traits.
    #
    # @return [Hash] JSON Schema document
    # @example
    #   schema = metadata.to_json_schema
    #   # => {
    #   #   type: "object",
    #   #   properties: {
    #   #     age: { type: "integer", minimum: 18, maximum: 65 },
    #   #     name: { type: "string" }
    #   #   },
    #   #   required: [:age, :name],
    #   #   "x-kumi-values": { ... },
    #   #   "x-kumi-traits": { ... }
    #   # }
    def to_json_schema
      JsonSchema::Generator.new(self).generate
    end

    # Returns processed declaration metadata.
    #
    # Transforms raw AST declaration nodes into clean, serializable metadata showing
    # declaration types and basic information. For raw AST nodes, use analyzer_state.
    #
    # @return [Hash<Symbol, Hash>] Declaration metadata keyed by name
    # @example
    #   metadata.declarations
    #   # => {
    #   #   :adult => { type: :trait, expression: ">=(input.age, 18)" },
    #   #   :tax_amount => { type: :value, expression: "multiply(input.income, tax_rate)" }
    #   # }
    def declarations
      @declarations ||= extract_declarations
    end

    # Returns processed dependency information.
    #
    # Transforms internal Edge objects into clean, serializable dependency data
    # showing relationships between declarations. For raw Edge objects, use analyzer_state.
    #
    # @return [Hash<Symbol, Array<Hash>>] Dependencies with plain data
    # @example
    #   metadata.dependencies
    #   # => {
    #   #   :tax_amount => [
    #   #     { to: :income, conditional: false },
    #   #     { to: :tax_rate, conditional: true, cascade_owner: :status }
    #   #   ]
    #   # }
    def dependencies
      @dependencies ||= extract_dependencies
    end

    # Returns reverse dependency lookup (dependents).
    #
    # Shows which declarations depend on each declaration. Useful for impact analysis
    # and understanding how changes to input fields or computed values affect other
    # parts of the schema.
    #
    # @return [Hash<Symbol, Array<Symbol>>] Dependent names keyed by declaration name
    def dependents
      @state[:dependents] || {}
    end

    # Returns leaf node categorization.
    #
    # Identifies declarations with no dependencies, categorized by type (trait/value).
    # Useful for understanding schema structure and identifying independent computations.
    #
    # @return [Hash<Symbol, Array<Symbol>>] Leaf declarations by category
    def leaves
      @state[:leaves] || {}
    end

    # Returns topologically sorted evaluation order.
    #
    # Provides the dependency-safe evaluation order for all declarations. Computed by
    # topological sort of the dependency graph. Critical for correct evaluation sequence
    # in runners and compilers.
    #
    # @return [Array<Symbol>] Declaration names in evaluation order
    def evaluation_order
      @state[:evaluation_order] || []
    end

    # Returns type inference results for all declarations.
    #
    # Maps declaration names to their inferred types based on expression analysis.
    # Includes both simple types (:boolean, :string, :float) and complex types
    # for array operations and structured data.
    #
    # @return [Hash<Symbol, Object>] Inferred types keyed by declaration name
    # @example
    #   types = metadata.inferred_types
    #   # => { :adult => :boolean, :tax_amount => :float, :totals => { array: :float } }
    def inferred_types
      @state[:inferred_types] || {}
    end

    # Returns cascade mutual exclusion analysis.
    #
    # Provides analysis results for cascade expressions including mutual exclusion
    # detection and satisfiability analysis. Used internally for optimization and
    # error detection in cascade logic.
    #
    # @return [Hash] Cascade analysis results
    def cascades
      @state[:cascades] || {}
    end

    # Returns array broadcasting operation metadata.
    #
    # Contains analysis of vectorized operations on array inputs, including element
    # access paths and broadcasting behavior. Used for generating efficient compiled
    # code for array operations.
    #
    # @return [Hash] Broadcasting operation metadata
    def broadcasts
      @state[:broadcasts] || {}
    end

    private

    def extract_declarations
      return {} unless @state[:declarations]

      @state[:declarations].transform_values do |node|
        {
          type: node.is_a?(Syntax::TraitDeclaration) ? :trait : :value,
          expression: expression_to_string(node.expression)
        }
      end
    end

    def extract_dependencies
      return {} unless @state[:dependencies]

      @state[:dependencies].transform_values do |edges|
        edges.map do |edge|
          result = { to: edge.to, conditional: edge.conditional }
          result[:cascade_owner] = edge.cascade_owner if edge.cascade_owner
          result
        end
      end
    end

    def extract_inputs
      return {} unless @state[:inputs]

      @state[:inputs].transform_values do |field_info|
        {
          type: normalize_type(field_info[:type]),
          domain: normalize_domain(field_info[:domain]),
          required: true
        }.compact
      end
    end

    def extract_values
      return {} unless @state[:dependencies]

      value_nodes = (@syntax_tree.values || []).flatten.select { |node| node.is_a?(Syntax::ValueDeclaration) }
      dependency_graph = @state[:dependencies] || {}
      inferred_types = @state[:inferred_types] || {}

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
      return {} unless @state[:dependencies]

      trait_nodes = (@syntax_tree.traits || []).flatten.select { |node| node.is_a?(Syntax::TraitDeclaration) }
      dependency_graph = @state[:dependencies] || {}

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
      when Syntax::CascadeExpression
        "cascade"
      else
        expr.class.name.split("::").last
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
