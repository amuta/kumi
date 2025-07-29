# frozen_string_literal: true

module Kumi
  module Analyzer
    Result = Struct.new(:definitions, :dependency_graph, :leaf_map, :topo_order, :decl_types, :state, keyword_init: true)

    module_function

    DEFAULT_PASSES = [
      Passes::NameIndexer,                # 1. Finds all names and checks for duplicates.
      Passes::InputCollector,             # 2. Collects field metadata from input declarations.
      Passes::DefinitionValidator,        # 3. Checks the basic structure of each rule.
      Passes::SemanticConstraintValidator, # 4. Validates DSL semantic constraints at AST level.
      Passes::DependencyResolver,         # 5. Builds the dependency graph.
      Passes::UnsatDetector,              # 6. Detects unsatisfiable constraints in rules.
      Passes::Toposorter,                 # 7. Creates the final evaluation order.
      Passes::TypeInferencer,             # 8. Infers types for all declarations (pure annotation).
      Passes::TypeConsistencyChecker,     # 9. Validates declared vs inferred type consistency.
      Passes::TypeChecker                 # 10. Validates types using inferred information.
    ].freeze

    def analyze!(schema, passes: DEFAULT_PASSES, **opts)
      state = AnalysisState.new(opts)
      errors = []

      state = run_analysis_passes(schema, passes, state, errors)
      handle_analysis_errors(errors) unless errors.empty?
      create_analysis_result(state)
    end

    def self.run_analysis_passes(schema, passes, state, errors)
      passes.each do |pass_class|
        pass_instance = pass_class.new(schema, state)
        begin
          state = pass_instance.run(errors)
        rescue StandardError => e
          errors << ErrorReporter.create_error(e.message, location: nil, type: :semantic)
        end
      end
      state
    end

    def self.handle_analysis_errors(errors)
      type_errors = errors.select { |e| e.type == :type }
      first_error_location = errors.first.location

      raise Errors::TypeError.new(format_errors(errors), first_error_location) if type_errors.any?

      raise Errors::SemanticError.new(format_errors(errors), first_error_location)
    end

    def self.create_analysis_result(state)
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
