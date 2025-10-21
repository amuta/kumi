# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      class ExecutionResult
        attr_reader :final_state, :errors, :failed_at_phase, :stopped

        def initialize(final_state:, errors: [], failed_at_phase: nil, stopped: false)
          @final_state = final_state
          @errors = errors
          @failed_at_phase = failed_at_phase
          @stopped = stopped
        end

        def self.success(final_state:, stopped: false)
          new(final_state: final_state, errors: [], failed_at_phase: nil, stopped: stopped)
        end

        def self.failure(final_state:, errors:, failed_at_phase:)
          new(final_state: final_state, errors: errors, failed_at_phase: failed_at_phase, stopped: false)
        end

        def succeeded?
          errors.empty?
        end

        def failed?
          !succeeded?
        end

        def error_count
          errors.size
        end
      end
    end
  end
end
