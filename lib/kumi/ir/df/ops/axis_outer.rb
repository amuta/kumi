# frozen_string_literal: true

module Kumi
  module IR
    module DF
      module Ops
        # Re-exposes `source` (an array over `source_axis`, belonging to a
        # DIFFERENT carrier array than the surrounding expression) as a fresh
        # inner axis. The result has the surrounding axes plus `axis` appended as
        # the new innermost axis, so element (i, j) reads source[j]. Where
        # AxisCross self-joins one array (A x A'), AxisOuter pairs two distinct
        # arrays (A x B): the broadcast that makes pixels-x-lights style
        # rasterization (and any two-array all-pairs) expressible.
        class AxisOuter < Node
          opcode :axis_outer

          def initialize(source:, axis:, source_axis:, **kwargs)
            super(
              inputs: [source],
              attributes: {
                axis: axis.to_sym,
                source_axis: source_axis.to_sym
              },
              **kwargs
            )
          end

          def source = inputs.first
          def axis = attributes[:axis]
          def source_axis = attributes[:source_axis]
        end
      end
    end
  end
end
