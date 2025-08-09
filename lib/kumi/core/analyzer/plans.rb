# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      # Typed plan structures for HIR (High-level Intermediate Representation)
      # These plans are produced by analyzer passes and consumed by LowerToIRPass
      # to generate LIR (Low-level IR) operations.
      module Plans
        # Scope plan: defines the dimensional execution context for a declaration
        Scope = Struct.new(:scope, :lifts, :join_hint, :arg_shapes, keyword_init: true) do
          def initialize(scope: [], lifts: [], join_hint: nil, arg_shapes: {})
            super
            freeze
          end

          def depth
            scope.size
          end

          def scalar?
            scope.empty?
          end
        end

        # Join plan: defines how to align multiple arguments at a target scope
        Join = Struct.new(:policy, :target_scope, keyword_init: true) do
          def initialize(policy: :zip, target_scope: [])
            super
            freeze
          end
        end

        # Reduce plan: defines how to reduce dimensions in array operations
        Reduce = Struct.new(:function, :axis, :source_scope, :result_scope, :flatten_args, keyword_init: true) do
          def initialize(function:, axis: [], source_scope: [], result_scope: [], flatten_args: [])
            super
            freeze
          end

          def total_reduction?
            axis == :all || result_scope.empty?
          end

          def partial_reduction?
            !total_reduction?
          end
        end
      end
    end
  end
end
