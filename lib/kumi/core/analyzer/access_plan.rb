module Kumi
  module Core
    module Analyzer
      # One plan for a specific path and mode (path:mode)
      AccessPlan = Struct.new(:path, :containers, :leaf, :scope, :depth, :mode,
                              :on_missing, :key_policy, :operations, keyword_init: true) do
        def initialize(path:, containers:, leaf:, scope:, depth:, mode:, on_missing:, key_policy:, operations:)
          super
          freeze
        end

        def accessor_key = "#{path}:#{mode}"
        def ndims        = depth
        def scalar?      = depth == 0
      end
    end
  end
end
