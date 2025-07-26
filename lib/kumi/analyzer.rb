# frozen_string_literal: true

require_relative "analyzer/analysis_state"

module Kumi
  module Analyzer
    Result = Struct.new(:definitions, :dependency_graph, :leaf_map, :topo_order, :decl_types, :state, keyword_init: true)

    module_function

    DEFAULT_PASSES = [
      Passes::NameIndexer,            # 1. Finds all names and checks for duplicates.
      Passes::InputCollector,         # 2. Collects field metadata from input declarations.
      Passes::DefinitionValidator,    # 3. Checks the basic structure of each rule.
      Passes::DependencyResolver,     # 4. Builds the dependency graph.
      Passes::UnsatDetector,          # 5. Detects unsatisfiable constraints in rules.
      Passes::Toposorter,             # 6. Creates the final evaluation order.
      Passes::TypeInferencer,         # 7. Infers types for all declarations (pure annotation).
      Passes::TypeConsistencyChecker, # 8. Validates declared vs inferred type consistency.
      Passes::TypeChecker             # 9. Validates types using inferred information.
    ].freeze

    def analyze!(schema, passes: DEFAULT_PASSES, **opts)
      state = AnalysisState.new(opts)
      errors = []

      passes.each do |pass_class|
        pass_instance = pass_class.new(schema, state)
        begin
          state = pass_instance.run(errors)
        rescue => e
          # Convert exceptions to errors and continue
          errors << ErrorReporter.create_error(e.message, location: nil, type: :semantic)
        end
      end

      unless errors.empty?
        # Check if we have type-specific errors to raise more specific exception
        type_errors = errors.select { |e| e.type == :type }
        first_error_location = errors.first.location

        raise Errors::TypeError.new(format_errors(errors), first_error_location) if type_errors.any?

        raise Errors::SemanticError.new(format_errors(errors), first_error_location)
      end

      Result.new(
        definitions: state[:definitions],
        dependency_graph: state[:dependency_graph],
        leaf_map: state[:leaf_map],
        topo_order: state[:topo_order],
        decl_types: state[:decl_types],
        state: state.to_h
      )
    end

    # Handle both old and new error formats for backward compatibility
    def format_errors(errors)
      return "" if errors.empty?

      errors.map(&:to_s).join("\n")
    end
  end
end
