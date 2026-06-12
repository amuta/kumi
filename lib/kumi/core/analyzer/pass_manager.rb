# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      class PassManager
        attr_reader :passes, :errors

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

            begin
              state = execute_pass(pass_class, pass_name, syntax_tree, state, errors, options)
            rescue StandardError => e
              error_obj = capture_exception(pass_name, e, errors)
              instrumentation.after_failure(e)
              return failure_result(state, [error_obj], pass_class, phase_index)
            end

            raise "Pass #{pass_name} returned #{state.class}, expected AnalysisState" unless state.is_a?(AnalysisState)

            instrumentation.after_success(state)
            Checkpoint.leaving(pass_name:, idx: phase_index, state:) if options[:checkpoint_enabled]

            return failure_result(state, errors, pass_class, phase_index) unless errors.empty?
            return ExecutionResult.success(final_state: state, stopped: true) if options[:stop_after] == pass_name
          end

          ExecutionResult.success(final_state: state)
        end

        private

        def execute_pass(pass_class, pass_name, syntax_tree, state, errors, options)
          pass_instance = pass_class.new(syntax_tree, state)

          if options[:profiling_enabled]
            Dev::Profiler.phase("analyzer.pass", pass: pass_name) { pass_instance.run(errors) }
          else
            pass_instance.run(errors)
          end
        end

        def capture_exception(pass_name, exception, errors)
          location_hint = exception.backtrace&.first
          message = if location_hint
                      "Error in Analysis Pass(#{pass_name}) at #{location_hint}: #{exception.message}"
                    else
                      "Error in Analysis Pass(#{pass_name}): #{exception.message}"
                    end
          error_obj = ErrorReporter.create_error(message, location: nil, type: :semantic, backtrace: exception.backtrace)
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

              raise "State[#{k}] not frozen: #{v.class}" unless v.frozen?
            end
          end
        end
      end
    end
  end
end
