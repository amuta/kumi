# frozen_string_literal: true

module Kumi
  module Analyzer
    Result = Struct.new(:definitions, :dependency_graph, :leaf_map, :topo_order, :decl_types, :state, keyword_init: true)
    ERROR_THRESHOLD_PASS = Core::Analyzer::Passes::LowerToIRPass

    DEFAULT_PASSES = [
      Core::Analyzer::Passes::NameIndexer,                     # 1. Finds all names and checks for duplicates.
      Core::Analyzer::Passes::InputCollector,                  # 2. Collects field metadata from input declarations.
      Core::Analyzer::Passes::DeclarationValidator,            # 4. Checks the basic structure of each rule.
      Core::Analyzer::Passes::SemanticConstraintValidator,     # 5. Validates DSL semantic constraints at AST level.
      Core::Analyzer::Passes::DependencyResolver,              # 6. Builds the dependency graph with conditional dependencies.
      Core::Analyzer::Passes::UnsatDetector,                   # 7. Detects unsatisfiable constraints and analyzes cascade mutual exclusion.
      Core::Analyzer::Passes::Toposorter,                      # 8. Creates the final evaluation order, allowing safe cycles.
      Core::Analyzer::Passes::BroadcastDetector,               # 9. Detects which operations should be broadcast over arrays.
      Core::Analyzer::Passes::TypeInferencerPass,              # 10. Infers types for all declarations (uses vectorization metadata).
      Core::Analyzer::Passes::TypeChecker,                     # 11. Validates types using inferred information.
      Core::Analyzer::Passes::InputAccessPlannerPass,          # 12. Plans access strategies for input fields.
      Core::Analyzer::Passes::ScopeResolutionPass,             # 13. Plans execution scope and lifting needs for declarations.
      Core::Analyzer::Passes::JoinReducePlanningPass,          # 14. Plans join/reduce operations (Generates IR Structs)
      Core::Analyzer::Passes::LowerToIRPass,                   # 15. Lowers the schema to IR (Generates IR Structs)
      Core::Analyzer::Passes::LoadInputCSE,                    # 16. Eliminates redundant load_input operations
      Core::Analyzer::Passes::IRDependencyPass,                # 17. Extracts IR-level dependencies for VM execution optimization
      Core::Analyzer::Passes::IRExecutionSchedulePass,         # 18. Builds a precomputed execution schedule.
      Core::Analyzer::Passes::NormalizeToNASTPass               # 19. Normalizes AST to uniform NAST representation
    ].freeze

    def self.analyze!(schema, passes: DEFAULT_PASSES, **opts)
      state = Core::Analyzer::AnalysisState.new(opts)
      errors = []

      state = run_analysis_passes(schema, passes, state, errors)
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
        raise handle_analysis_errors(errors) if (ERROR_THRESHOLD_PASS == pass_class) && !errors.empty?

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
