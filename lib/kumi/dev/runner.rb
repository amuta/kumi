# frozen_string_literal: true

module Kumi
  module Dev
    module Runner
      Result = Struct.new(:state, :ir, :errors, keyword_init: true) do
        def ok?
          errors.empty?
        end
      end

      module_function

      def run(schema, opts = {})
        # Set ENV vars for debug/checkpoint based on opts
        setup_env_vars(opts)

        state = Core::Analyzer::AnalysisState.new
        errors = []

        begin
          final_state = Dev::Profiler.phase("text.analyzer") do
            Kumi::Analyzer.run_analysis_passes(schema, Kumi::Analyzer::DEFAULT_PASSES, state, errors)
          end
          ir = final_state[:ir_module]
          
          result = Result.new(
            state: final_state,
            ir: ir,
            errors: errors
          )
          
          # Report trace file if enabled
          if opts[:trace] && defined?(@trace_file) && @trace_file
            trace_file_path = @trace_file
            result.define_singleton_method(:trace_file) { trace_file_path }
          end
          
          result
        rescue StandardError => e
          # Convert exception to error if not already captured
          errors << e.message unless errors.include?(e.message)
          Result.new(
            state: state,
            ir: nil,
            errors: errors
          )
        end
      end

      private

      def self.setup_env_vars(opts)
        if opts[:trace]
          ENV["KUMI_DEBUG_STATE"] = "1"
          trace_file = ENV["KUMI_DEBUG_FILE"] || "tmp/state_trace.jsonl"
          ENV["KUMI_DEBUG_FILE"] = trace_file
          
          # Store for later reporting
          @trace_file = trace_file
        end

        if opts[:snap]
          ENV["KUMI_CHECKPOINT_PHASES"] = opts[:snap]
        end

        if opts[:snap_dir]
          ENV["KUMI_CHECKPOINT_DIR"] = opts[:snap_dir]
        end

        if opts[:resume_from]
          ENV["KUMI_CHECKPOINT_RESUME_FROM"] = opts[:resume_from]
        end

        if opts[:resume_at]
          ENV["KUMI_CHECKPOINT_RESUME_AT"] = opts[:resume_at]
        end

        if opts[:stop_after]
          ENV["KUMI_CHECKPOINT_STOP_AFTER"] = opts[:stop_after]
        end
      end
    end
  end
end