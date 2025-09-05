# frozen_string_literal: true

module Kumi
  module Codegen
    module Planning
      # ReducePlan holds lowering info for a single Reduce op.
      #
      # Fields:
      #   op_id, axis, arg_id, reducer_fn, result_depth, carrier_spec
      #   contrib_depth :: Integer   (where AccAdd happens)
      #   reset_depth   :: Integer   (where AccReset happens; may be -1)
      #   bind_depth    :: Integer   (where v = acc happens)
      #   nested        :: Boolean   (arg is another reduce)
      class ReducePlan
        attr_reader :op_id, :axis, :result_depth, :arg_id, :reducer_fn,
                    :kernel_id_hint, :carrier_spec, :contrib_depth,
                    :reset_depth, :bind_depth, :nested

        def self.from_op(op:, access_plan:)
          raise "not a reduce op" unless op.kind == :reduce

          axis_raw   = op.attrs[:axis] || op.attrs["axis"]
          reducer_fn = op.attrs[:fn]   || op.attrs["fn"] or raise "Reduce op #{op.id} missing :fn"

          axis_str = String(axis_raw).strip
          raise "Reduce op #{op.id} missing/empty :axis (got #{axis_raw.inspect})" if axis_str.empty?

          axis_sym     = axis_str.to_sym
          result_depth = Array(op.stamp_axes).length
          reducer_fn   = reducer_fn.to_s

          required_prefix = Array(op.stamp_axes).map(&:to_sym)
          carrier_spec    = choose_reduce_carrier(axis_sym, required_prefix, access_plan)

          new(
            op_id: op.id,
            axis: axis_sym,
            result_depth: result_depth,
            arg_id: op.args.first,
            reducer_fn: reducer_fn,
            kernel_id_hint: nil,
            carrier_spec: carrier_spec,
            access_plan: access_plan,
            contrib_depth: nil,
            reset_depth:   nil,
            bind_depth:    nil,
            nested:        false
          )
        end

        def initialize(op_id:, axis:, result_depth:, arg_id:, reducer_fn:, kernel_id_hint:, carrier_spec:, access_plan:,
                       contrib_depth:, reset_depth:, bind_depth:, nested:)
          @op_id          = op_id
          @axis           = axis
          @result_depth   = result_depth
          @arg_id         = arg_id
          @reducer_fn     = reducer_fn
          @kernel_id_hint = kernel_id_hint
          @carrier_spec   = carrier_spec
          @access         = access_plan

          @contrib_depth  = contrib_depth
          @reset_depth    = reset_depth
          @bind_depth     = bind_depth
          @nested         = nested
        end

        def with_placement(contrib_depth:, reset_depth:, bind_depth:, nested:)
          self.class.new(
            op_id: @op_id,
            axis: @axis,
            result_depth: @result_depth,
            arg_id: @arg_id,
            reducer_fn: @reducer_fn,
            kernel_id_hint: @kernel_id_hint,
            carrier_spec: @carrier_spec,
            access_plan: @access,
            contrib_depth: contrib_depth,
            reset_depth:   reset_depth,
            bind_depth:    bind_depth,
            nested:        nested
          )
        end

        def via_path
          Array(@carrier_spec.path).map(&:to_s)
        end

        # Canonical JSON entry (string keys on serialization side are fine; here we keep Ruby symbols)
        def to_entry
          {
            op_id: @op_id,
            axis: @axis,
            via_path: via_path,
            reducer_fn: @reducer_fn,
            result_depth: @result_depth,
            arg_id: @arg_id,
            contrib_depth: @contrib_depth,
            reset_depth: @reset_depth,
            bind_depth: @bind_depth,
            nested: @nested
          }
        end

        def self.choose_reduce_carrier(axis, required_prefix, access_plan)
          axis_sym = axis.to_sym
          raise "blank reduce axis" if axis_sym == :""

          candidates = access_plan.inputs_by_path.values.select do |input_spec|
            input_spec.axis_loops.any? { |loop| (loop[:axis] || loop["axis"]).to_sym == axis_sym }
          end
          raise "No input path carries reduce axis #{axis_sym.inspect}" if candidates.empty?

          compatible = candidates.select do |spec|
            consumed_axes = access_plan.consumes_axes(spec.path)
            axis_index    = consumed_axes.index(axis.to_sym)
            next false if axis_index.nil?
            actual_prefix = consumed_axes.take(axis_index)
            actual_prefix == required_prefix
          end

          if compatible.empty?
            candidate_info = candidates.map do |s|
              consumed = access_plan.consumes_axes(s.path)
              axis_idx = consumed.index(axis.to_sym)
              prefix   = axis_idx ? consumed.take(axis_idx) : consumed
              "#{s.path.join('.')} (prefix: #{prefix.inspect})"
            end.join(", ")
            raise "No prefix-compatible carrier for reduce axis #{axis.inspect}. " \
                  "Required prefix: #{required_prefix.inspect}. Candidates: #{candidate_info}"
          end

          compatible.find { |s| s.path.map(&:to_s) == [axis.to_s] } ||
            compatible.min_by { |s| s.axis_loops.length } ||
            compatible.min_by { |s| s.path.map(&:to_s).join("/") }
        end
      end
    end
  end
end
