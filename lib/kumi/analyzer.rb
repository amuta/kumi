# frozen_string_literal: true

module Kumi
  module Analyzer
    Result = Struct.new(:definitions, :dependency_graph, :leaf_map, :topo_order, :decl_types, :state, keyword_init: true)
    Passes = Core::Analyzer::Passes
    ERROR_THRESHOLD_PASS = Passes::NormalizeToNASTPass

    DEFAULT_PASSES = [
      Passes::NameIndexer,                     # 1. Finds all names and checks for duplicates.
      Passes::InputCollector,                  # 2. Collects field metadata from input declarations.
      Passes::DeclarationValidator,            # 3. Checks the basic structure of each rule.
      Passes::SemanticConstraintValidator,     # 4. Validates DSL semantic constraints at AST level.
      Passes::DependencyResolver,              # 5. Builds the dependency graph with conditional dependencies.
      Passes::UnsatDetector,                   # 6. Detects unsatisfiable constraints and analyzes cascade mutual exclusion.
      Passes::Toposorter,                      # 7. Creates the final evaluation order, allowing safe cycles.
      # Passes::BroadcastDetector,               # 8. Detects which operations should be broadcast over arrays.
      # Passes::TypeInferencerPass,              # 9. Infers types for all declarations (uses vectorization metadata).
      # Passes::TypeChecker,                     # 10. Validates types using inferred information.
      Passes::InputAccessPlannerPass # 11. Plans access strategies for input fields.
      # Passes::ScopeResolutionPass,             # 12. Plans execution scope and lifting needs for declarations.
      # Passes::JoinReducePlanningPass,          # 13. Plans join/reduce operations (Generates IR Structs)
      # Passes::LowerToIRPass,                   # 14. Lowers the schema to IR (Generates IR Structs)
      # Passes::LoadInputCSE,                    # 15. Eliminates redundant load_input operations
      # Passes::IRDependencyPass,                # 16. Extracts IR-level dependencies for VM execution optimization
      # Passes::IRExecutionSchedulePass          # 17. Builds a precomputed execution schedule.
    ].freeze

    # Pipeline passes for the determinisitic NAST->LIR approach
    HIR_TO_LIR_PASSES = [
      Passes::NormalizeToNASTPass,             # Normalizes AST to uniform NAST representation
      Passes::ConstantFoldingPass,             # Folds constant expressions in NAST
      Passes::NASTDimensionalAnalyzerPass,     # Extracts dimensional and type metadata from NAST
      Passes::SNASTPass,                       # Creates Semantic NAST with dimensional stamps and execution plans
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
      stop_after = Core::Analyzer::Checkpoint.stop_after

      registry ||= Kumi::RegistryV2.load
      state = Core::Analyzer::AnalysisState.new(opts).with(:registry, registry).with(:schema_digest, schema_digest)
      state, stopped = run_analysis_passes(schema, passes, state, errors)
      return create_analysis_result(state) if stopped

      state, stopped = run_analysis_passes(schema, HIR_TO_LIR_PASSES, state, errors)
      return create_analysis_result(state) if stopped

      state, stopped = run_analysis_passes(schema, RUBY_TARGET_PASSES, state, errors)

      handle_analysis_errors(errors) unless errors.empty?
      create_analysis_result(state)
    end

    def self.run_analysis_passes(schema, passes, state, errors)
      # Resume from a saved state if configured
      state = Core::Analyzer::Checkpoint.load_initial_state(state)

      debug_on = Core::Analyzer::Debug.enabled?
      resume_at  = Core::Analyzer::Checkpoint.resume_at
      stop_after = Core::Analyzer::Checkpoint.stop_after
      skipping   = !!resume_at
      stopped    = false

      passes.each_with_index do |pass_class, idx|
        raise handle_analysis_errors(errors) if !errors.empty? && (ERROR_THRESHOLD_PASS == pass_class)

        pass_name = pass_class.name.split("::").last

        if skipping
          skipping = false if pass_name == resume_at
          next if skipping
        end

        Core::Analyzer::Checkpoint.entering(pass_name:, idx:, state:)

        before = state.to_h if debug_on
        Core::Analyzer::Debug.reset_log(pass: pass_name) if debug_on

        t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        pass_instance = pass_class.new(schema, state)
        begin
          state = Dev::Profiler.phase("analyzer.pass", pass: pass_name) do
            pass_instance.run(errors)
          end
        rescue StandardError => e
          # TODO: - GREATLY improve this, need to capture the context of the error
          # and the pass that failed and line number if relevant
          message = "Error in Analysis Pass(#{pass_name}): #{e.message}"
          errors << Core::ErrorReporter.create_error(message, location: nil, type: :semantic, backtrace: e.backtrace)

          if debug_on
            logs = Core::Analyzer::Debug.drain_log
            elapsed_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0) * 1000).round(2)

            Core::Analyzer::Debug.emit(
              pass: pass_name,
              diff: {},
              elapsed_ms: elapsed_ms,
              logs: logs + [{ level: :error, id: :exception, message: e.message, error_class: e.class.name }]
            )
          end

          raise
        end
        unless state.is_a? Kumi::Core::Analyzer::AnalysisState
          raise "Pass #{pass_name} returned a '#{state.class}', expected 'AnalysisState'"
        end

        elapsed_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0) * 1000).round(2)

        if debug_on
          after = state.to_h

          # Optional immutability guard
          if ENV["KUMI_DEBUG_REQUIRE_FROZEN"] == "1"
            (after || {}).each do |k, v|
              if v.nil? || v.is_a?(Numeric) || v.is_a?(Symbol) || v.is_a?(TrueClass) || v.is_a?(FalseClass) || (v.is_a?(String) && v.frozen?)
                next
              end
              raise "State[#{k}] not frozen: #{v.class}" unless v.frozen?
            end
          end

          diff = Core::Analyzer::Debug.diff_state(before, after)
          logs = Core::Analyzer::Debug.drain_log

          Core::Analyzer::Debug.emit(
            pass: pass_name,
            diff: diff,
            elapsed_ms: elapsed_ms,
            logs: logs
          )
        end

        Core::Analyzer::Checkpoint.leaving(pass_name:, idx:, state:)

        if stop_after && pass_name == stop_after
          stopped = true
          break
        end
      end
      [state, stopped]
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
