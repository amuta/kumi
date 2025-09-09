# frozen_string_literal: true

module Kumi
  module Dev
    # Alias to the execution engine profiler for cross-layer access
    Profiler = Kumi::Core::IR::ExecutionEngine::Profiler

    # Load profile runner for CLI
    autoload :ProfileRunner, "kumi/dev/profile_runner"

    # Load profile aggregator for data analysis
    autoload :ProfileAggregator, "kumi/dev/profile_aggregator"
  end
end
