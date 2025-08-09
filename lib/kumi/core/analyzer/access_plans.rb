module Kumi
  module Core
    module Analyzer
      module AccessPlans
        # One plan for a specific path and mode (path:mode)
        Plan = Struct.new(:path, :containers, :leaf, :scope, :depth, :mode,
                          :on_missing, :key_policy, :operations, keyword_init: true) do
          def initialize(path:, containers:, leaf:, scope:, depth:, mode:, on_missing:, key_policy:, operations:)
            super
            freeze
          end

          def accessor_key = "#{path}:#{mode}"
          def ndims        = depth
          def scalar?      = depth == 0
        end

        # Map path -> [Plan, Plan, ...] (different modes)
        Plans = Struct.new(:by_path, keyword_init: true) do
          def initialize(by_path: {}) = super(by_path: by_path.freeze).freeze
          def [](path)                = by_path[path] || []
          def paths                   = by_path.keys
          def modes_for(path)         = self[path].map(&:mode)
          def find(path, mode)        = self[path].find { |p| p.mode == mode }
        end
      end
    end
  end
end
