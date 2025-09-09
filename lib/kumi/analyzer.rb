# frozen_string_literal: true

module Kumi
  module Analyzer
    Result = Struct.new(:definitions, :dependency_graph, :leaf_map, :topo_order, :decl_types, :state, keyword_init: true)
    ERROR_THRESHOLD_PASS = Core::Analyzer::Passes::LowerToIRPass

    DEFAULT_PASSES = [
      Core::Analyzer::Passes::NameIndexer,                     # 1. Finds all names and checks for duplicates.
      Core::Analyzer::Passes::InputCollector,                  # 2. Collects field metadata from input declarations.
      Core::Analyzer::Passes::DeclarationValidator,            # 3. Checks the basic structure of each rule.
      Core::Analyzer::Passes::SemanticConstraintValidator,     # 4. Validates DSL semantic constraints at AST level.
      Core::Analyzer::Passes::DependencyResolver,              # 5. Builds the dependency graph with conditional dependencies.
      Core::Analyzer::Passes::UnsatDetector,                   # 6. Detects unsatisfiable constraints and analyzes cascade mutual exclusion.
      Core::Analyzer::Passes::Toposorter,                      # 7. Creates the final evaluation order, allowing safe cycles.
      Core::Analyzer::Passes::BroadcastDetector,               # 8. Detects which operations should be broadcast over arrays.
      Core::Analyzer::Passes::TypeInferencerPass,              # 9. Infers types for all declarations (uses vectorization metadata).
      Core::Analyzer::Passes::TypeChecker,                     # 10. Validates types using inferred information.
      Core::Analyzer::Passes::InputAccessPlannerPass,          # 11. Plans access strategies for input fields.
      Core::Analyzer::Passes::ScopeResolutionPass,             # 12. Plans execution scope and lifting needs for declarations.
      Core::Analyzer::Passes::JoinReducePlanningPass,          # 13. Plans join/reduce operations (Generates IR Structs)
      Core::Analyzer::Passes::LowerToIRPass,                   # 14. Lowers the schema to IR (Generates IR Structs)
      Core::Analyzer::Passes::LoadInputCSE,                    # 15. Eliminates redundant load_input operations
      Core::Analyzer::Passes::IRDependencyPass,                # 16. Extracts IR-level dependencies for VM execution optimization
      Core::Analyzer::Passes::IRExecutionSchedulePass          # 17. Builds a precomputed execution schedule.
    ].freeze

    # Parallel pipeline passes for NAST->HIR->IR approach
    # These run independently to build side tables for deterministic HIR generation
    SIDE_TABLE_PASSES = [
      Core::Analyzer::Passes::NormalizeToNASTPass,             # Normalizes AST to uniform NAST representation
      Core::Analyzer::Passes::NASTDimensionalAnalyzerPass,     # Extracts dimensional and type metadata from NAST
      Core::Analyzer::Passes::SNASTPass,                       # Creates Semantic NAST with dimensional stamps and execution plans
      Core::Analyzer::Passes::AttachTerminalInfoPass,          # Attaches key_chain info to InputRef nodes
      Core::Analyzer::Passes::LowerToLIRPass,                  # Lowers the schema to LIR (LIR Structs)
      Core::Analyzer::Passes::LIRInlineDeclarationsPass,       # Inlines LoadDeclaration when site axes == decl axes
      Core::Analyzer::Passes::LIRLocalCSEPass,                 # Local CSE optimization for pure LIR operations
      Core::Analyzer::Passes::LIRValidationPass,               # Validates LIR structural and contextual correctness
      # Core::Analyzer::Passes::ContractCheckerPass,             # Validates contracts and structural invariants
      # Core::Analyzer::Passes::LowerToIRV2Pass,                 # Lowers SNAST to backend-agnostic IRV2 representation
      # Core::Analyzer::Passes::AssembleIRV2Pass,                # Assembles final IRV2 JSON structure
      # Core::Analyzer::Passes::KernelBindingPass                # Generates kernel binding manifest for target backend
    ].freeze

    def self.analyze!(schema, passes: DEFAULT_PASSES, side_tables: true, registry: nil, **opts)
      errors = []
      
      registry ||= Kumi::RegistryV2.load
      state = Core::Analyzer::AnalysisState.new(opts).with(:registry, registry)
      state = run_analysis_passes(schema, passes, state, errors)
      # Run side table passes for SNAST->LIR
      state = run_analysis_passes(schema, SIDE_TABLE_PASSES, state, errors) if side_tables

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

      passes.each_with_index do |pass_class, idx|
        raise handle_analysis_errors(errors) if !errors.empty? && # (ERROR_THRESHOLD_PASS == pass_class)

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
            pass_state = pass_instance.run(errors)
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

        break if stop_after && pass_name == stop_after
      end
      state
    end

    def self.handle_analysis_errors(errors)
      if errors.first.is_a? String
        raise Kumi::Errors::AnalysisError, "\n" + errors.join("\n")
      end

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
