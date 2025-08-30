# frozen_string_literal: true

module Kumi
  module Codegen
    module Planning
      # ReducePlan captures all information needed to lower a single Reduce op.
      #
      # Interface:
      #   .from_op(op:, access_plan:) -> ReducePlan
      #   #axis -> Symbol               (the reduced axis token)
      #   #result_depth -> Integer      (|arg.axes| - 1)
      #   #arg_id -> Integer
      #   #reducer_fn -> String         (e.g., "agg.sum")
      #   #kernel_id_hint -> String|nil (if you map fn->kernel id upstream)
      #   #len_call(idx_var:, data_var:) -> String  (use carrier for axis)
      class ReducePlan
        attr_reader :axis, :result_depth, :arg_id, :reducer_fn, :kernel_id_hint, :carrier_spec

        def self.from_op(op:, access_plan:)
          raise "not a reduce op" unless op.kind == :reduce

          axis_sym = (op.attrs[:axis] || op.attrs["axis"]) or raise "Reduce op #{op.id} missing :axis attribute"
          reducer_fn = (op.attrs[:fn] || op.attrs["fn"]) or raise "Reduce op #{op.id} missing :fn attribute"
          
          axis_sym = axis_sym.to_sym
          arg_axes = Array(op.stamp_axes) + [axis_sym] # arg stamp includes axis by IR convention
          result_depth = arg_axes.length - 1
          reducer_fn = reducer_fn.to_s # e.g. "agg.sum"

          # Select carrier with proper site prefix (result site = op.stamp_axes)
          required_prefix = Array(op.stamp_axes).map(&:to_sym)
          carrier_spec = choose_reduce_carrier(axis_sym, required_prefix, access_plan)

          new(
            axis: axis_sym,
            result_depth: result_depth,
            arg_id: op.args.first,
            reducer_fn: reducer_fn,
            kernel_id_hint: nil, # leave nil unless you pre-bind fn->kernel_id
            carrier_spec: carrier_spec,
            access_plan: access_plan
          )
        end

        def initialize(axis:, result_depth:, arg_id:, reducer_fn:, kernel_id_hint:, carrier_spec:, access_plan:)
          @axis = axis
          @result_depth = result_depth
          @arg_id = arg_id
          @reducer_fn = reducer_fn
          @kernel_id_hint = kernel_id_hint
          @carrier_spec = carrier_spec
          @access = access_plan
        end

        def len_call(idx_var: "idx", data_var: "@d")
          method = @access.axis_len_method_name(@axis, @carrier_spec.path)
          "#{method}(#{data_var}, #{idx_var})"
        end

        private

        def self.choose_reduce_carrier(axis, required_prefix, access_plan)
          candidates = access_plan.carriers_for_axis(axis)
          raise "No input path carries reduce axis #{axis.inspect}" if candidates.empty?

          # Filter candidates that have compatible prefix for the reduce site
          compatible_candidates = candidates.select do |spec|
            consumed_axes = access_plan.consumes_axes(spec.path)
            axis_index = consumed_axes.index(axis.to_sym)
            
            if axis_index.nil?
              false # doesn't actually consume this axis
            else
              # Check if prefix before this axis matches required prefix
              actual_prefix = consumed_axes.take(axis_index)
              actual_prefix == required_prefix
            end
          end

          if compatible_candidates.empty?
            candidate_info = candidates.map { |s| 
              consumed = access_plan.consumes_axes(s.path)
              axis_idx = consumed.index(axis.to_sym)
              prefix = axis_idx ? consumed.take(axis_idx) : consumed
              "#{s.path.join('.')} (prefix: #{prefix.inspect})"
            }.join(", ")
            
            raise "No prefix-compatible carrier for reduce axis #{axis.inspect}. " \
                  "Required prefix: #{required_prefix.inspect}. " \
                  "Candidates: #{candidate_info}"
          end

          # Deterministic choice among compatible candidates
          compatible_candidates.find { |s| s.path.map(&:to_s) == [axis.to_s] } ||
          compatible_candidates.min_by { |s| s.chain.length } ||
          compatible_candidates.sort_by { |s| s.path.map(&:to_s).join("/") }.first
        end
      end
    end
  end
end
