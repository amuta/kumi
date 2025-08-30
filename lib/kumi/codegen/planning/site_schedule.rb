# frozen_string_literal: true

module Kumi
  module Codegen
    module Planning
      # SiteSchedule places each op at its unique minimal site
      # (depth = |op.stamp.axes|), and exposes hoist & per-depth lists.
      #
      # Interface:
      #   .build(decl:) -> SiteSchedule
      #   #hoisted -> [OpSpec]         (depth 0)
      #   #ops_at_depth(d) -> [OpSpec] (d >= 0, in original topological order)
      #   #depth_for(op_id) -> Integer
      class SiteSchedule
        attr_reader :decl_name, :decl_axes, :result_id

        def self.build(decl:)
          new(
            decl_name: decl.name,
            decl_axes: decl.axes,
            result_id: decl.result_id,
            ops: decl.ops
          )
        end

        def initialize(decl_name:, decl_axes:, result_id:, ops:)
          @decl_name = decl_name
          @decl_axes = Array(decl_axes).map(&:to_sym)
          @result_id = result_id
          @ops       = ops

          @depth_by_id = {}
          @by_depth    = Hash.new { |h, k| h[k] = [] }

          @ops.each do |op|
            depth = Array(op.stamp_axes).length
            @depth_by_id[op.id] = depth
            @by_depth[depth] << op
          end
        end

        def hoisted
          @by_depth[0]
        end

        def ops_at_depth(d)
          @by_depth[d] || []
        end

        def max_depth
          @by_depth.keys.max || 0
        end

        def depth_for(op_id)
          @depth_by_id.fetch(op_id)
        end
      end
    end
  end
end
