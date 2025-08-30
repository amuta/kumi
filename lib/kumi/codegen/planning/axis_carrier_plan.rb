# frozen_string_literal: true

module Kumi
  module Codegen
    module Planning
      # AxisCarrierPlan picks ONE authoritative input path as the "carrier"
      # of length for each declaration axis (bounds only; NOT used for reads).
      #
      # Interface:
      #   .build(decl_axes:, access_plan:) -> AxisCarrierPlan
      #   #carrier_for(axis) -> InputSpec
      class AxisCarrierPlan
        def self.build(decl_axes:, access_plan:, required_prefix: [])
          mapping = {}
          decl_axes.each do |axis|
            candidates = access_plan.carriers_for_axis(axis)
            raise "No input path carries axis #{axis.inspect}" if candidates.empty?

            # Calculate required prefix for this axis at this declaration site
            axis_required_prefix = required_prefix + decl_axes.take_while { |ax| ax != axis }
            
            # Filter candidates that have compatible prefix
            compatible_candidates = candidates.select do |spec|
              consumed_axes = access_plan.consumes_axes(spec.path)
              axis_index = consumed_axes.index(axis.to_sym)
              
              if axis_index.nil?
                false # doesn't actually consume this axis
              else
                # Check if prefix before this axis matches required prefix
                actual_prefix = consumed_axes.take(axis_index)
                actual_prefix == axis_required_prefix
              end
            end

            if compatible_candidates.empty?
              candidate_info = candidates.map { |s| 
                consumed = access_plan.consumes_axes(s.path)
                axis_idx = consumed.index(axis.to_sym)
                prefix = axis_idx ? consumed.take(axis_idx) : consumed
                "#{s.path.join('.')} (prefix: #{prefix.inspect})"
              }.join(", ")
              
              raise "No prefix-compatible carrier for axis #{axis.inspect}. " \
                    "Required prefix: #{axis_required_prefix.inspect}. " \
                    "Candidates: #{candidate_info}"
            end

            # Deterministic choice among compatible candidates
            chosen = compatible_candidates.find { |s| s.path.map(&:to_s) == [axis.to_s] } ||
                     compatible_candidates.min_by { |s| s.chain.length } ||
                     compatible_candidates.sort_by { |s| s.path.map(&:to_s).join("/") }.first

            mapping[axis.to_sym] = chosen
          end
          new(mapping, access_plan)
        end

        def initialize(mapping, access_plan)
          @mapping = mapping # { axis(Symbol) => InputSpec }
          @access  = access_plan
        end

        def carrier_for(axis_sym)
          @mapping.fetch(axis_sym.to_sym)
        end

        # Backend-agnostic entry for one axis
        def entry_for(axis_sym)
          spec = carrier_for(axis_sym)
          { axis: axis_sym.to_sym, via_path: Array(spec.path).map(&:to_s) }
        end

        # Array of {axis, via_path} for all outer decl axes
        def to_entries
          @mapping.map { |axis, _| entry_for(axis) }
        end

      end
    end
  end
end
