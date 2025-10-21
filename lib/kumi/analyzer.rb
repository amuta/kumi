# frozen_string_literal: true

module Kumi
  module Analyzer
    Result = Struct.new(:definitions, :dependency_graph, :leaf_map, :topo_order, :decl_types, :state, keyword_init: true)
    Passes = Core::Analyzer::Passes
    ERROR_THRESHOLD_PASS = Passes::NormalizeToNASTPass

    DEFAULT_PASSES = [
      Passes::NameIndexer,                     # 1. Finds all names and checks for duplicates.
      Passes::InputCollector,                  # 2. Collects field metadata from input declarations.
      Passes::InputFormSchemaPass,             # 3. Builds minimal form schema from input metadata.
      Passes::DeclarationValidator,            # 4. Checks the basic structure of each rule.
      Passes::SemanticConstraintValidator,     # 5. Validates DSL semantic constraints at AST level.
      Passes::DependencyResolver,              # 6. Builds the dependency graph with conditional dependencies.
      Passes::Toposorter,                      # 7. Creates the final evaluation order, allowing safe cycles.
      Passes::InputAccessPlannerPass           # 8. Plans access strategies for input fields.
    ].freeze

    # Pipeline passes for the determinisitic NAST->LIR approach
    HIR_TO_LIR_PASSES = [
      Passes::NormalizeToNASTPass,             # Normalizes AST to uniform NAST representation
      Passes::ConstantFoldingPass,             # Folds constant expressions in NAST
      Passes::NASTDimensionalAnalyzerPass,     # Extracts dimensional and type metadata from NAST
      Passes::SNASTPass,                       # Creates Semantic NAST with dimensional stamps and execution plans
      Passes::UnsatDetector,                   # Detects impossible constraints with resolved function IDs and SNAST metadata
      Passes::OutputSchemaPass,                # Builds minimal output schema from SNAST
      Passes::AttachTerminalInfoPass,          # Attaches key_chain info to InputRef nodes
      Passes::AttachAnchorsPass,
      Passes::PrecomputeAccessPathsPass,
      Passes::LIR::LowerPass,                  # Lowers the schema to LIR (LIR Structs)
      Passes::LIR::HoistScalarReferencesPass,
      Passes::LIR::InlineDeclarationsPass,     # Inlines LoadDeclaration when site axes == decl axes
      Passes::LIR::LocalCSEPass,               # Local CSE optimization for pure LIR operations
      Passes::LIR::InstructionSchedulingPass,
      Passes::LIR::LoopFusionPass,
      Passes::LIR::LocalCSEPass,               # Local CSE optimization for pure LIR operations
      Passes::LIR::DeadCodeEliminationPass, # Removes dead code
      Passes::LIR::KernelBindingPass, # Binds kernels to LIR operations
      Passes::LIR::LoopInvariantCodeMotionPass
      # Passes::LIR::ValidationPass # Validates LIR structural and contextual correctness
    ].freeze

    RUBY_TARGET_PASSES = [
      Passes::LIR::ConstantPropagationPass, # Ruby uses this Intra-block constant propagation
      Passes::LIR::DeadCodeEliminationPass, # Removes dead code
      Passes::Codegen::RubyPass, # Generates ruby code from LIR
      Passes::Codegen::JsPass
    ]

    def self.analyze!(schema, passes: DEFAULT_PASSES, registry: nil, **opts)
      errors = []
      schema_digest = schema.digest
      Core::Analyzer::Checkpoint.stop_after

      registry ||= Kumi::RegistryV2.load
      state = Core::Analyzer::AnalysisState.new(opts).with(:registry, registry).with(:schema_digest, schema_digest)
      state, stopped = run_analysis_passes(schema, passes, state, errors)
      return create_analysis_result(state) if stopped

      state, stopped = run_analysis_passes(schema, HIR_TO_LIR_PASSES, state, errors)
      return create_analysis_result(state) if stopped

      state, = run_analysis_passes(schema, RUBY_TARGET_PASSES, state, errors)

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
                            if pass_name == resume_at
                              break passes[idx..]
                            end
                          end.flatten.compact
                        else
                          passes
                        end

      # Check for error threshold pass
      if !errors.empty? && filtered_passes.include?(ERROR_THRESHOLD_PASS)
        raise handle_analysis_errors(errors)
      end

      # Use PassManager for orchestration
      manager = Core::Analyzer::PassManager.new(filtered_passes)
      options = {
        checkpoint_enabled: true,
        debug_enabled: debug_on,
        profiling_enabled: true,
        stop_after: stop_after
      }

      result = manager.run(schema, state, errors, options)

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
