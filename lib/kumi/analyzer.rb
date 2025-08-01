# frozen_string_literal: true

module Kumi
  module Analyzer
    Result = Struct.new(:definitions, :dependency_graph, :leaf_map, :topo_order, :decl_types, :state, keyword_init: true)

    module_function

    DEFAULT_PASSES = [
      Core::Analyzer::Passes::NameIndexer,                     # 1. Finds all names and checks for duplicates.
      Core::Analyzer::Passes::InputCollector,                  # 2. Collects field metadata from input declarations.
      Core::Analyzer::Passes::DeclarationValidator,            # 3. Checks the basic structure of each rule.
      Core::Analyzer::Passes::SemanticConstraintValidator,     # 4. Validates DSL semantic constraints at AST level.
      Core::Analyzer::Passes::DependencyResolver,              # 5. Builds the dependency graph with conditional dependencies.
      Core::Analyzer::Passes::UnsatDetector,                   # 6. Detects unsatisfiable constraints and analyzes cascade mutual exclusion.
      Core::Analyzer::Passes::Toposorter,                      # 7. Creates the final evaluation order, allowing safe cycles.
      Core::Analyzer::Passes::BroadcastDetector, # 8. Detects which operations should be broadcast over arrays (must run before type inference).
      Core::Analyzer::Passes::TypeInferencer,                  # 9. Infers types for all declarations (uses vectorization metadata).
      Core::Analyzer::Passes::TypeConsistencyChecker,          # 10. Validates declared vs inferred type consistency.
      Core::Analyzer::Passes::TypeChecker                      # 11. Validates types using inferred information.
    ].freeze

    def self.analyze!(schema, passes: DEFAULT_PASSES, **opts)
      state = Core::Analyzer::AnalysisState.new(opts)
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
          errors << Core::ErrorReporter.create_error(e.message, location: nil, type: :semantic)
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
        definitions: state[:declarations],
        dependency_graph: state[:dependencies],
        leaf_map: state[:leaves],
        topo_order: state[:evaluation_order],
        decl_types: state[:inferred_types],
        state: state.to_h
      )
    end

    # Handle both old and new error formats for backward compatibility
    def self.format_errors(errors)
      return "" if errors.empty?

      errors.map(&:to_s).join("\n")
    end
  end
end
