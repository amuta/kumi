# frozen_string_literal: true

module Kumi
  module Analyzer
    Result = Struct.new(:definitions, :dependency_graph, :leaf_map, :topo_order, :decl_types, :state, keyword_init: true)

    DEFAULT_PASSES = [
      Core::Analyzer::Passes::NameIndexer,                     # 1. Finds all names and checks for duplicates.
      Core::Analyzer::Passes::InputCollector,                  # 2. Collects field metadata from input declarations.
      Core::Analyzer::Passes::DeclarationValidator,            # 3. Checks the basic structure of each rule.
      Core::Analyzer::Passes::SemanticConstraintValidator,     # 4. Validates DSL semantic constraints at AST level.
      Core::Analyzer::Passes::DependencyResolver,              # 5. Builds the dependency graph with conditional dependencies.
      Core::Analyzer::Passes::Toposorter,                      # 7. Creates the final evaluation order, allowing safe cycles.
      Core::Analyzer::Passes::CascadeConstraintValidator,      # 8. Validates cascade_and usage constraints.
      Core::Analyzer::Passes::CascadeDesugarPass,              # 9. Desugar cascade_and to regular and operations.
      Core::Analyzer::Passes::CallNameNormalizePass,           # 10. Normalize function names to canonical basenames.
      Core::Analyzer::Passes::BroadcastDetector,               # 11. Detects which operations should be broadcast over arrays.
      Core::Analyzer::Passes::CrossScopeValidator,             # 12. Validates cross-scope operations and throws semantic errors.
      Core::Analyzer::Passes::TypeInferencerPass,              # 13. Infers types for all declarations (uses vectorization metadata).
      Core::Analyzer::Passes::TypeConsistencyChecker,          # 14. Validates declared vs inferred type consistency.
      Core::Analyzer::Passes::FunctionSignaturePass,           # 15. Resolves NEP-20 signatures for function calls.
      Core::Analyzer::Passes::TypeCheckerV2,                   # 16. Computes CallExpression result dtypes and validates constraints via RegistryV2.
      Core::Analyzer::Passes::AmbiguityResolverPass,           # 17. Resolves ambiguous functions using complete type information.
      Core::Analyzer::Passes::UnsatDetector,                   # 6. Detects unsatisfiable constraints and analyzes cascade mutual exclusion.
      Core::Analyzer::Passes::InputAccessPlannerPass,          # 18. Plans access strategies for input fields.
      Core::Analyzer::Passes::ScopeResolutionPass,             # 19. Plans execution scope and lifting needs for declarations.
      Core::Analyzer::Passes::JoinReducePlanningPass,          # 20. Plans join/reduce operations and stores in node_index (Generates IR Structs)
      Core::Analyzer::Passes::ContractCheckPass,               # 21. Validates analyzer state contracts.
      Core::Analyzer::Passes::LowerToIRPass                    # 22. Lowers the schema to IR (Generates IR Structs)
    ].freeze

    def self.analyze!(schema, passes: DEFAULT_PASSES, **opts)
      state = Core::Analyzer::AnalysisState.new(opts)
      errors = []
      registry = Kumi::Registry.registry_v2 # Use the facade that includes custom functions
      state = state.with(:registry, registry)

      state = run_analysis_passes(schema, passes, state, errors)
      handle_analysis_errors(errors) unless errors.empty?
      create_analysis_result(state)
    end

    def self.run_analysis_passes(schema, passes, state, errors)
      passes.each do |pass_class|
        pass_instance = pass_class.new(schema, state)
        pass_name = pass_class.name.split("::").last

        # Count errors before this pass
        errors_before = errors.length

        begin
          state = pass_instance.run(errors)
        rescue StandardError => e
          # TODO: - GREATLY improve this, need to capture the context of the error
          # and the pass that failed and line number if relevant
          message = "Error in Analysis Pass(#{pass_name}): #{e.message}"
          errors << Core::ErrorReporter.create_error(message, location: nil, type: :semantic, backtrace: e.backtrace)

          raise e
        end

        # Annotate any new errors with the pass name
        errors[errors_before..].each do |error|
          error.message = "[#{pass_name}] #{error.message}" if error.respond_to?(:message) && !error.message.include?("Analysis Pass")
        end

        # Stop analysis if this pass added errors
        break if errors.length > errors_before
      end
      state
    end

    def self.handle_analysis_errors(errors)
      type_errors = errors.select { |e| e.type == :type }
      semantic_errors = errors.select { |e| e.type == :semantic }
      first_error_location = errors.first.location

      raise Errors::TypeError.new(Core::ErrorReporter.format_messages_only(errors), first_error_location) if type_errors.any?

      if first_error_location || semantic_errors
        raise Errors::SemanticError.new(Core::ErrorReporter.format_messages_only(errors),
                                        first_error_location)
      end

      raise Errors::AnalysisError, Core::ErrorReporter.format_errors(errors)
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

      backtrace = errors.first.backtrace

      message = errors.map(&:to_s).join("\n")

      message.tap do |msg|
        if backtrace && !backtrace.empty?
          msg << "\n\nBacktrace:\n"
          msg << backtrace[0..10].join("\n") # Limit to first 10 lines for readability
        end
      end
    end
  end
end
