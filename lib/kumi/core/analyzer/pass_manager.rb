# frozen_string_literal: true

require "timeout"

module Kumi
  module Core
    module Analyzer
      # Raised when a single analysis pass exceeds its wall-clock budget. This
      # turns a runaway / non-terminating pass into a located failure ("which
      # pass, how long, how big the input was") instead of an indefinite hang.
      class PassBudgetError < StandardError
        attr_reader :pass_name, :elapsed_ms, :budget_ms

        def initialize(pass_name:, elapsed_ms:, budget_ms:, size_hint: nil)
          @pass_name = pass_name
          @elapsed_ms = elapsed_ms
          @budget_ms = budget_ms
          size = size_hint ? " (#{size_hint})" : ""
          super("Pass #{pass_name} exceeded its compile budget: ran > #{budget_ms}ms#{size}. " \
                "This usually means the schema is too large or hit a pathological " \
                "compile path. Raise the budget with KUMI_PASS_BUDGET_MS or simplify the schema.")
        end
      end

      class PassManager
        # Per-pass identity threaded through guarded execution.
        PassRun = Struct.new(:pass_class, :phase_index, :instrumentation, keyword_init: true) do
          def pass_name = instrumentation.pass_name
        end

        attr_reader :passes, :errors

        # Default per-pass wall-clock budget in milliseconds. 0 disables the
        # check. Overridable via the KUMI_PASS_BUDGET_MS env var or the
        # :pass_budget_ms option. A generous default so only true runaways trip.
        DEFAULT_PASS_BUDGET_MS = 20_000

        def initialize(passes)
          @passes = passes
          @errors = []
        end

        def run(syntax_tree, initial_state = nil, errors = [], options = {})
          state = initial_state || AnalysisState.new

          passes.each_with_index do |pass_class, phase_index|
            pass_name = pass_class.name.split("::").last
            Checkpoint.entering(pass_name:, idx: phase_index, state:) if options[:checkpoint_enabled]

            instrumentation = Instrumentation.new(pass_name, options)
            instrumentation.before(state)

            run = PassRun.new(pass_class: pass_class, phase_index: phase_index, instrumentation: instrumentation)
            state, budget_failure = run_one_pass(run, syntax_tree, state, errors, options)
            return budget_failure if budget_failure

            instrumentation.after_success(state)
            Checkpoint.leaving(pass_name:, idx: phase_index, state:) if options[:checkpoint_enabled]

            return failure_result(state, errors, pass_class, phase_index) unless errors.empty?
            return ExecutionResult.success(final_state: state, stopped: true) if options[:stop_after] == pass_name
          end

          ExecutionResult.success(final_state: state)
        end

        private

        def run_one_pass(run, syntax_tree, state, errors, options)
          pass_class = run.pass_class
          pass_name = run.pass_name
          enforce_reads!(pass_class, pass_name, state)
          contract_before = state.to_h
          state = execute_pass(pass_class, pass_name, syntax_tree, state, errors, options)
          enforce_writes!(pass_class, pass_name, contract_before, state)

          unless state.is_a?(AnalysisState)
            raise Kumi::Core::Errors::CompilerBug, "pass #{pass_name} returned #{state.class}, expected AnalysisState"
          end

          [state, nil]
        rescue PassBudgetError => e
          # A runaway pass is a recoverable resource limit, not a fault:
          # surface it as a normal located pass failure.
          error_obj = capture_exception(pass_name, e, errors)
          run.instrumentation.after_failure(e)
          [state, failure_result(state, [error_obj], pass_class, run.phase_index)]
        rescue Kumi::Core::Errors::Error => e
          # User-reachable errors are accumulated, not raised; an internal error
          # class reaching here (CompilerBug, ConfigurationError,
          # UnsupportedFeature) is a genuine fault — let it crash loudly.
          run.instrumentation.after_failure(e)
          raise
        rescue StandardError => e
          # An unexpected exception in pass code is a compiler bug, not a user
          # error. Surface it as one instead of disguising it.
          run.instrumentation.after_failure(e)
          raise Kumi::Core::Errors::CompilerBug, "#{pass_name}: #{e.class}: #{e.message}"
        end

        def execute_pass(pass_class, pass_name, syntax_tree, state, errors, options)
          pass_instance = pass_class.new(syntax_tree, state)

          with_budget(pass_name, syntax_tree, options) do
            # A pass that calls halt_pass! has already recorded a located error
            # and stops here; we return the unchanged state and let the
            # non-empty `errors` array drive the failure (no exception wrapping).
            catch(Passes::PassBase::HALT) do
              if options[:profiling_enabled]
                Dev::Profiler.phase("analyzer.pass", pass: pass_name) { pass_instance.run(errors) }
              else
                pass_instance.run(errors)
              end
            end || state
          end
        end

        # Run the block under a wall-clock budget. On timeout we raise a
        # PassBudgetError (caught by run's rescue and surfaced as a normal,
        # located pass failure) instead of letting the compile hang forever.
        def with_budget(pass_name, syntax_tree, options, &)
          budget_ms = pass_budget_ms(options)
          return yield if budget_ms <= 0

          started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          begin
            Timeout.timeout(budget_ms / 1000.0, &)
          rescue Timeout::Error
            elapsed_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
            raise PassBudgetError.new(
              pass_name: pass_name,
              elapsed_ms: elapsed_ms,
              budget_ms: budget_ms,
              size_hint: size_hint(syntax_tree)
            )
          end
        end

        def pass_budget_ms(options)
          return options[:pass_budget_ms].to_i if options.key?(:pass_budget_ms)

          env = ENV.fetch("KUMI_PASS_BUDGET_MS", nil)
          return env.to_i if env && !env.empty?

          DEFAULT_PASS_BUDGET_MS
        end

        # Best-effort "how big is this schema" string for the error message.
        def size_hint(syntax_tree)
          decls = []
          decls.concat(Array(syntax_tree.values)) if syntax_tree.respond_to?(:values)
          decls.concat(Array(syntax_tree.traits)) if syntax_tree.respond_to?(:traits)
          return nil if decls.empty?

          "#{decls.size} declarations"
        rescue StandardError
          nil
        end

        def enforce_reads!(pass_class, pass_name, state)
          return unless pass_class.respond_to?(:contract_declared?) && pass_class.contract_declared?

          missing = pass_class.declared_reads.reject { |key| state.key?(key) }
          return if missing.empty?

          raise Kumi::Core::Errors::CompilerBug,
                "#{pass_name} declares reads #{missing.inspect} but they are missing from analysis state"
        end

        def enforce_writes!(pass_class, pass_name, before, state)
          return unless pass_class.respond_to?(:contract_declared?) && pass_class.contract_declared?
          return unless state.is_a?(AnalysisState)

          after = state.to_h
          changed = after.keys.select { |key| !before.key?(key) || !before[key].equal?(after[key]) }
          undeclared = changed - pass_class.declared_writes
          return if undeclared.empty?

          raise Kumi::Core::Errors::CompilerBug,
                "#{pass_name} wrote undeclared state keys #{undeclared.inspect} (declared writes: #{pass_class.declared_writes.inspect})"
        end

        def capture_exception(_pass_name, exception, errors)
          error_obj = ErrorReporter.create_error(exception.message, location: nil, type: :semantic, backtrace: exception.backtrace)
          errors << error_obj
          error_obj
        end

        def failure_result(state, errors, pass_class, phase_index)
          phase = ExecutionPhase.new(pass_class: pass_class, index: phase_index)
          converted = errors.map do |error|
            PassFailure.new(
              message: error.message,
              phase: phase_index,
              pass_name: phase.pass_name,
              location: error.respond_to?(:location) ? error.location : nil
            )
          end
          ExecutionResult.failure(final_state: state, errors: converted, failed_at_phase: phase_index)
        end

        class Instrumentation
          attr_reader :pass_name

          def initialize(pass_name, options)
            @pass_name = pass_name
            @debug = options[:debug_enabled]
            @profiling = options[:profiling_enabled]
          end

          def before(state)
            @before = state.to_h if @debug
            Debug.reset_log(pass: @pass_name) if @debug
            @t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC) if @profiling
          end

          def after_success(state)
            return unless @debug

            after = state.to_h
            enforce_frozen!(after) if ENV["KUMI_DEBUG_REQUIRE_FROZEN"] == "1"
            Debug.emit(pass: @pass_name, diff: Debug.diff_state(@before, after), elapsed_ms: elapsed_ms, logs: Debug.drain_log)
          end

          def after_failure(exception)
            return unless @debug

            logs = Debug.drain_log + [{ level: :error, id: :exception, message: exception.message, error_class: exception.class.name }]
            Debug.emit(pass: @pass_name, diff: {}, elapsed_ms: elapsed_ms, logs: logs)
          end

          private

          def elapsed_ms
            return 0 unless @profiling && @t0

            ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - @t0) * 1000).round(2)
          end

          def enforce_frozen!(after)
            (after || {}).each do |k, v|
              next if v.nil? || v.is_a?(Numeric) || v.is_a?(Symbol) || v.is_a?(TrueClass) || v.is_a?(FalseClass) ||
                      (v.is_a?(String) && v.frozen?)

              raise Kumi::Core::Errors::CompilerBug, "State[#{k}] not frozen: #{v.class}" unless v.frozen?
            end
          end
        end
      end
    end
  end
end
