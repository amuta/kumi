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
      class ReducePlan
        attr_reader :op_id, :axis, :result_depth, :arg_id, :reducer_fn, :kernel_id_hint, :carrier_spec

        def self.from_op(op:, access_plan:)

          raise "not a reduce op" unless op.kind == :reduce

          axis_raw = op.attrs[:axis] || op.attrs["axis"]
          reducer_fn = op.attrs[:fn] || op.attrs["fn"] or raise "Reduce op #{op.id} missing :fn attribute"

          
          # Handle empty/missing axis
          axis_str = String(axis_raw).strip
          raise "Reduce op #{op.id} missing or empty :axis attribute (got #{axis_raw.inspect})" if axis_str.empty?

          axis_sym = axis_str.to_sym
          arg_axes = Array(op.stamp_axes) + [axis_sym] # arg stamp includes axis by IR convention
          result_depth = arg_axes.length - 1
          reducer_fn = reducer_fn.to_s # e.g. "agg.sum"


          # Select carrier with proper site prefix (result site = op.stamp_axes)
          required_prefix = Array(op.stamp_axes).map(&:to_sym)
          carrier_spec = choose_reduce_carrier(axis_sym, required_prefix, access_plan)

          new(
            op_id: op.id,
            axis: axis_sym,
            result_depth: result_depth,
            arg_id: op.args.first,
            reducer_fn: reducer_fn,
            kernel_id_hint: nil, # leave nil unless you pre-bind fn->kernel_id
            carrier_spec: carrier_spec,
            access_plan: access_plan
          )
        end

        def initialize(op_id:, axis:, result_depth:, arg_id:, reducer_fn:, kernel_id_hint:, carrier_spec:, access_plan:)
          @op_id = op_id
          @axis = axis
          @result_depth = result_depth
          @arg_id = arg_id
          @reducer_fn = reducer_fn
          @kernel_id_hint = kernel_id_hint
          @carrier_spec = carrier_spec
          @access = access_plan
        end

        def via_path
          Array(@carrier_spec.path).map(&:to_s)
        end

        # Backend-agnostic shape for plan export / codegen adapters
        def to_entry
          {
            op_id: @op_id,
            axis: @axis,
            via_path: via_path,
            reducer_fn: @reducer_fn,
            result_depth: @result_depth,
            arg_id: @arg_id
          }
        end

        def self.choose_reduce_carrier(axis, required_prefix, access_plan)
          axis_sym = axis.to_sym
          
          # Validate axis is not empty
          raise "blank reduce axis" if axis_sym == :""
          
          # Find all inputs that have this axis in their axis_loops
          candidates = access_plan.inputs_by_path.values.select do |input_spec|
            has_axis = input_spec.axis_loops.any? { |loop| (loop[:axis] || loop["axis"]).to_sym == axis_sym }
            has_axis
          end
          
          raise "No input path carries reduce axis #{axis_sym.inspect}" if candidates.empty?

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
            candidate_info = candidates.map do |s|
              consumed = access_plan.consumes_axes(s.path)
              axis_idx = consumed.index(axis.to_sym)
              prefix = axis_idx ? consumed.take(axis_idx) : consumed
              "#{s.path.join('.')} (prefix: #{prefix.inspect})"
            end.join(", ")

            raise "No prefix-compatible carrier for reduce axis #{axis.inspect}. " \
                  "Required prefix: #{required_prefix.inspect}. " \
                  "Candidates: #{candidate_info}"
          end

          # Deterministic choice among compatible candidates
          compatible_candidates.find { |s| s.path.map(&:to_s) == [axis.to_s] } ||
            compatible_candidates.min_by { |s| s.axis_loops.length } ||
            compatible_candidates.min_by { |s| s.path.map(&:to_s).join("/") }
        end
      end
    end
  end
end
