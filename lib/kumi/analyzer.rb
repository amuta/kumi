# frozen_string_literal: true

module Kumi
  module Analyzer
    Result = Struct.new(:definitions, :dependency_graph, :leaf_map, :topo_order, :decl_types, :state, keyword_init: true)

    module_function

    DEFAULT_PASSES = [
      Passes::NameIndexer,            # 1. Finds all names and checks for duplicates.
      Passes::InputCollector,         # 2. Collects field metadata from input declarations.
      Passes::DefinitionValidator,    # 3. Checks the basic structure of each rule.
      Passes::DependencyResolver,     # 4. Builds the dependency graph.
      Passes::CycleDetector,          # 5. Finds cycles in the dependency graph.
      Passes::Toposorter,             # 6. Creates the final evaluation order.
      Passes::TypeInferencer,         # 7. Infers types for all declarations (pure annotation).
      Passes::TypeChecker             # 8. Validates types using inferred information.
    ].freeze

    def analyze!(schema, passes: DEFAULT_PASSES, **opts)
      analysis_state = { opts: opts } # renamed from :summary
      errors = []

      passes.each { |klass| klass.new(schema, analysis_state).run(errors) }

      raise Errors::SemanticError, format(errors) unless errors.empty?

      Result.new(
        definitions: analysis_state[:definitions].freeze,
        dependency_graph: analysis_state[:dependency_graph].freeze,
        leaf_map: analysis_state[:leaf_map].freeze,
        topo_order: analysis_state[:topo_order].freeze,
        decl_types: analysis_state[:decl_types].freeze,
        state: analysis_state.freeze
      )
    end

    def format(errs) = errs.map { |loc, msg| "at #{loc || '?'}: #{msg}" }.join("\n")
  end
end
