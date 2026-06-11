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

            # Checkpoint support
            Checkpoint.entering(pass_name:, idx: phase_index, state:) if options[:checkpoint_enabled]

            # Debug support
            debug_on = options[:debug_enabled]
            before = state.to_h if debug_on
            Debug.reset_log(pass: pass_name) if debug_on

            # Performance profiling support
            t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC) if options[:profiling_enabled]

            begin
              pass_instance = pass_class.new(syntax_tree, state)

              if options[:profiling_enabled]
                state = Dev::Profiler.phase("analyzer.pass", pass: pass_name) do
                  pass_instance.run(errors)
                end
              else
                state = pass_instance.run(errors)
              end
            rescue StandardError => e
              # Capture exception context
              location_hint = e.backtrace&.first
              message = if location_hint
                          "Error in Analysis Pass(#{pass_name}) at #{location_hint}: #{e.message}"
                        else
                          "Error in Analysis Pass(#{pass_name}): #{e.message}"
                        end
              error_obj = ErrorReporter.create_error(message, location: nil, type: :semantic, backtrace: e.backtrace)
              errors << error_obj

              if debug_on
                logs = Debug.drain_log
                elapsed_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0) * 1000).round(2) if options[:profiling_enabled]
                Debug.emit(
                  pass: pass_name,
                  diff: {},
                  elapsed_ms: elapsed_ms || 0,
                  logs: logs + [{ level: :error, id: :exception, message: e.message, error_class: e.class.name }]
                )
              end

              # Return failure result instead of raising - let caller decide what to do
              phase = ExecutionPhase.new(pass_class: pass_class, index: phase_index)
              converted_error = PassFailure.new(
                message: error_obj.message,
                phase: phase_index,
                pass_name: phase.pass_name,
                location: error_obj.location
              )
              return ExecutionResult.failure(
                final_state: state,
                errors: [converted_error],
                failed_at_phase: phase_index
              )
            end

            # Type checking (PassManager enforces AnalysisState)
            unless state.is_a?(AnalysisState)
              raise "Pass #{pass_name} returned #{state.class}, expected AnalysisState"
            end

            # Debug logging with state diff
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

              diff = Debug.diff_state(before, after)
              logs = Debug.drain_log
              elapsed_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0) * 1000).round(2) if options[:profiling_enabled]

              Debug.emit(
                pass: pass_name,
                diff: diff,
                elapsed_ms: elapsed_ms || 0,
                logs: logs
              )
            end

            # Checkpoint support
            Checkpoint.leaving(pass_name:, idx: phase_index, state:) if options[:checkpoint_enabled]

            # Handle errors
            if !errors.empty?
              phase = ExecutionPhase.new(pass_class: pass_class, index: phase_index)
              converted_errors = errors.map do |error|
                PassFailure.new(
                  message: error.message,
                  phase: phase_index,
                  pass_name: phase.pass_name,
                  location: error.respond_to?(:location) ? error.location : nil
                )
              end
              return ExecutionResult.failure(
                final_state: state,
                errors: converted_errors,
                failed_at_phase: phase_index
              )
            end

            # Check stop_after
            if options[:stop_after] && pass_name == options[:stop_after]
              return ExecutionResult.success(final_state: state, stopped: true)
            end
          end

          ExecutionResult.success(final_state: state)
        end
      end
    end
  end
end
