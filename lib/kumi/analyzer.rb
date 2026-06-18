# frozen_string_literal: true

module Kumi
  module Analyzer
    Result = Struct.new(:definitions, :dependency_graph, :leaf_map, :topo_order, :decl_types, :state, keyword_init: true)
    Passes = Core::Analyzer::Passes
    ERROR_THRESHOLD_PASS = Passes::NormalizeToNASTPass

    DEFAULT_PASSES = [
      Passes::NameIndexerPass,
      Passes::ImportAnalysisPass,
      Passes::InputCollectorPass,
      Passes::InputFormSchemaPass,
      Passes::DeclarationValidatorPass,
      Passes::SemanticConstraintValidatorPass,
      Passes::DependencyResolverPass,
      Passes::ToposorterPass,
      Passes::InputAccessPlannerPass
    ].freeze

    # Lowering pipeline: NAST -> SNAST -> DFIR -> VecIR -> LoopIR
    LOWERING_PASSES = [
      Passes::NormalizeToNASTPass,
      Passes::ConstantFoldingPass,
      Passes::NASTDimensionalAnalyzerPass,
      Passes::SNASTPass,
      Passes::UnsatDetectorPass,
      Passes::OutputSchemaPass,
      Passes::AttachTerminalInfoPass,
      Passes::AttachAnchorsPass,
      Passes::PrecomputeAccessPathsPass,
      Passes::LowerToDFIRPass,
      Passes::DFValidatePass,
      Passes::Vec::LowerPass,
      Passes::VecValidatePass,
      Passes::Loop::LowerPass,
      Passes::LoopValidatePass
    ].freeze

    TARGET_PASSES = [
      Passes::Codegen::LoopRubyPass,
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

      # `errors` is the canonical accumulator: passes append to it, and
      # PassManager appends any captured exception to it before deriving
      # result.errors (PassFailure objects) from the same array. Re-appending
      # result.errors here would surface every failure a second time, so we
      # don't — the originals are already in `errors`.

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
