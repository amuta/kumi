# frozen_string_literal: true

module Kumi
  module Analyzer
    Result = Struct.new(:definitions, :dependency_graph, :leaf_map, :topo_order, :decl_types, :state, keyword_init: true)
    Passes = Core::Analyzer::Passes
    ERROR_THRESHOLD_PASS = Passes::NormalizeToNASTPass

    DEFAULT_PASSES = [
      Passes::NameIndexerPass,                     # 1. Finds all names and checks for duplicates.
      Passes::ImportAnalysisPass,              # 2. Loads source schemas for imports (NEW).
      Passes::InputCollectorPass,                  # 3. Collects field metadata from input declarations.
      Passes::InputFormSchemaPass,             # 4. Builds minimal form schema from input metadata.
      Passes::DeclarationValidatorPass,            # 5. Checks the basic structure of each rule.
      Passes::SemanticConstraintValidatorPass,     # 6. Validates DSL semantic constraints at AST level.
      Passes::DependencyResolverPass,              # 7. Builds the dependency graph with conditional dependencies.
      Passes::ToposorterPass,                      # 8. Creates the final evaluation order, allowing safe cycles.
      Passes::InputAccessPlannerPass           # 9. Plans access strategies for input fields.
    ].freeze

    # Lowering pipeline: NAST -> SNAST -> DFIR -> VecIR -> LoopIR
    LOWERING_PASSES = [
      Passes::NormalizeToNASTPass,             # Normalizes AST to uniform NAST representation
      Passes::ConstantFoldingPass,             # Folds constant expressions in NAST
      Passes::NASTDimensionalAnalyzerPass,     # Extracts dimensional and type metadata from NAST
      Passes::SNASTPass,                       # Creates Semantic NAST with dimensional stamps and execution plans
      Passes::UnsatDetectorPass,                   # Detects impossible constraints with resolved function IDs and SNAST metadata
      Passes::OutputSchemaPass,                # Builds minimal output schema from SNAST
      Passes::AttachTerminalInfoPass,          # Attaches key_chain info to InputRef nodes
      Passes::AttachAnchorsPass,
      Passes::PrecomputeAccessPathsPass,
      Passes::LowerToDFIRPass,                 # Lowers SNAST into DFIR and stores it in analysis state
      Passes::DFValidatePass,                  # Validates DFIR invariants before Vec lowering
      Passes::Vec::LowerPass,                  # Lowers DFIR into VecIR and stores it in analysis state
      Passes::VecValidatePass,                 # Validates VecIR invariants before Loop lowering
      Passes::Loop::LowerPass,                 # Lowers VecIR into LoopIR and stores it in analysis state
      Passes::LoopValidatePass                 # Validates LoopIR invariants before codegen
    ].freeze

    TARGET_PASSES = [
      Passes::Codegen::LoopRubyPass, # Generates Ruby code from LoopIR
      Passes::Codegen::LoopJsPass
    ].freeze

    def self.analyze!(schema, passes: DEFAULT_PASSES, registry: nil, **opts)
      errors = []
      schema_digest = schema.digest
      Core::Analyzer::Checkpoint.stop_after

      registry ||= Kumi::RegistryV2.load
      state = Core::Analyzer::AnalysisState.new(opts).with(:registry, registry).with(:schema_digest, schema_digest)
      state, stopped = run_analysis_passes(schema, passes, state, errors)
      return create_analysis_result(state) if stopped

      handle_analysis_errors(errors) unless errors.empty?

      state, stopped = run_analysis_passes(schema, LOWERING_PASSES, state, errors)
      return create_analysis_result(state) if stopped

      handle_analysis_errors(errors) unless errors.empty?

      state, = run_analysis_passes(schema, TARGET_PASSES, state, errors)

      handle_analysis_errors(errors) unless errors.empty?
      create_analysis_result(state)
    end

    def self.run_analysis_passes(schema, passes, state, errors)
      # Resume from a saved state if configured
      state = Core::Analyzer::Checkpoint.load_initial_state(state)

      # Prepare options for PassManager
      debug_on = Core::Analyzer::Debug.enabled?
      resume_at  = Core::Analyzer::Checkpoint.resume_at
      stop_after = Core::Analyzer::Checkpoint.stop_after

      # Filter passes based on checkpoint resume point
      filtered_passes = if resume_at
                          passes.each_with_index do |pass_class, idx|
                            pass_name = pass_class.name.split("::").last
                            break passes[idx..] if pass_name == resume_at
                          end.flatten.compact
                        else
                          passes
                        end

      # Check for error threshold pass
      raise handle_analysis_errors(errors) if !errors.empty? && filtered_passes.include?(ERROR_THRESHOLD_PASS)

      # Use PassManager for orchestration
      manager = Core::Analyzer::PassManager.new(filtered_passes)
      options = {
        checkpoint_enabled: true,
        debug_enabled: debug_on,
        profiling_enabled: true,
        stop_after: stop_after
      }

      result = manager.run(schema, state, errors, options)

      # Convert PassFailure errors back to ErrorEntry for consistency
      if result.failed?
        result.errors.each do |pass_failure|
          errors << Core::ErrorReporter.create_error(
            pass_failure.message,
            location: pass_failure.location,
            type: :semantic
          )
        end
      end

      [result.final_state, result.stopped || false]
    end

    def self.handle_analysis_errors(errors)
      raise Kumi::Errors::AnalysisError, "\n" + errors.join("\n") if errors.first.is_a? String

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
