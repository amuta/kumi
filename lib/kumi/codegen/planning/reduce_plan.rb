# frozen_string_literal: true

module Kumi
  module Codegen
    module Planning
      # ReducePlan captures all information needed to lower a single Reduce op.
      #
      # Interface:
      #   .from_op(op:, carrier_plan:, access_plan:) -> ReducePlan
      #   #axis -> Symbol               (the reduced axis token)
      #   #result_depth -> Integer      (|arg.axes| - 1)
      #   #arg_id -> Integer
      #   #reducer_fn -> String         (e.g., "agg.sum")
      #   #kernel_id_hint -> String|nil (if you map fn->kernel id upstream)
      #   #len_call(idx_var:, data_var:) -> String  (use carrier for axis)
      class ReducePlan
        attr_reader :axis, :result_depth, :arg_id, :reducer_fn, :kernel_id_hint

        def self.from_op(op:, carrier_plan:, access_plan:)
          raise "not a reduce op" unless op.kind == :reduce

          axis_sym = (op.attrs[:axis] || op.attrs["axis"]).to_sym
          arg_axes = Array(op.stamp_axes) + [axis_sym] # arg stamp includes axis by IR convention
          result_depth = arg_axes.length - 1
          reducer_fn = (op.attrs[:fn] || op.attrs["fn"]).to_s # e.g. "agg.sum"

          new(
            axis: axis_sym,
            result_depth: result_depth,
            arg_id: op.args.first,
            reducer_fn: reducer_fn,
            kernel_id_hint: nil, # leave nil unless you pre-bind fn->kernel_id
            carrier_plan: carrier_plan,
            access_plan: access_plan
          )
        end

        def initialize(axis:, result_depth:, arg_id:, reducer_fn:, kernel_id_hint:, carrier_plan:, access_plan:)
          @axis = axis
          @result_depth = result_depth
          @arg_id = arg_id
          @reducer_fn = reducer_fn
          @kernel_id_hint = kernel_id_hint
          @carriers = carrier_plan
          @access = access_plan
        end

        def len_call(idx_var: "idx", data_var: "@d")
          spec = @carriers.carrier_for(@axis)
          method = @access.axis_len_method_name(@axis, spec.path)
          "#{method}(#{data_var}, #{idx_var})"
        end
      end
    end
  end
end
