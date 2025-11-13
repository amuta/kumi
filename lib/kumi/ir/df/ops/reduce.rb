# frozen_string_literal: true

module Kumi
  module IR
    module DF
      module Ops
        class Reduce < Node
          opcode :reduce

          def initialize(fn:, arg:, over_axes:, **kwargs)
            super(
              inputs: [arg],
              attributes: {
                fn: fn.to_sym,
                over_axes: Array(over_axes).map(&:to_sym)
              },
              **kwargs
            )
          end

          def reducer = attributes[:fn]
          def over_axes = attributes[:over_axes]
        end
      end
    end
  end
end
