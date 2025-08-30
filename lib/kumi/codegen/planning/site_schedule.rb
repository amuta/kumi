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
            site_axes = Array(op.stamp_axes).map(&:to_sym)
            depth = site_axes.length
            
            # Validate that op site axes are consistent with the declaration structure
            # The site must either be:
            # 1. A prefix of declaration axes (normal case), OR  
            # 2. The declaration axes plus additional deeper axes (for ops that will be reduced)
            unless prefix_of?(site_axes, @decl_axes) || prefix_of?(@decl_axes, site_axes)
              raise "Op #{op.id} site #{site_axes.inspect} is incompatible with decl axes #{@decl_axes.inspect} (#{@decl_name})"
            end
            
            @depth_by_id[op.id] = depth
            @by_depth[depth] << op
          end
        end

        def hoisted_scalars
          @by_depth[0].reject { |op| op.kind == :reduce }
        end

        def root_reduces
          @by_depth[0].select { |op| op.kind == :reduce }
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

        private

        def prefix_of?(small, big)
          small.each_with_index.all? { |ax, i| big[i] == ax }
        end
      end
    end
  end
end
