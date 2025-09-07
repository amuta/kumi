# frozen_string_literal: true

module Kumi
  module Codegen
    module Planning
      # AxisCarrierPlan picks ONE authoritative input path as the "carrier"
      # of length for each declaration axis (bounds only; NOT used for reads).
      class AxisCarrierPlan
        def self.build(decl_axes:, access_plan:, required_prefix: [])
          mapping = {}

          decl_axes.each do |axis|
            ax = axis.to_sym

            # 1) Find candidate input paths that contain the target axis.
            candidates = access_plan.inputs_by_fqn.values.select do |spec|
              spec["navigation_steps"].any? { |step| step["kind"] == "array_loop" && step["axis"].to_sym == ax }
            end
            raise "No input path carries axis #{axis.inspect}" if candidates.empty?

            # 2) Determine the required prefix of axes at this point in the calculation.
            req_prefix = (required_prefix + decl_axes.take_while { |a| a != axis }).map!(&:to_sym)

            # 3) Filter candidates by prefix-compatibility.
            compatible = candidates.select do |spec|
              # First, filter to get only the loop steps from the unified navigation plan.
              loop_steps = spec["navigation_steps"].select { |step| step["kind"] == "array_loop" }
              
              loop_for_ax = loop_steps.find { |lp| lp["axis"].to_sym == ax }
              next false unless loop_for_ax

              depth = loop_steps.index(loop_for_ax) || 0
              actual_prefix = loop_steps.take(depth).map { |lp| lp["axis"].to_sym }
              actual_prefix == req_prefix
            end

            if compatible.empty?
              details = candidates.map do |s|
                # Also filter here for correct error reporting.
                loop_steps = s["navigation_steps"].select { |step| step["kind"] == "array_loop" }
                carried = loop_steps.map { |lp| lp["axis"].to_sym }
                idx = carried.index(ax)
                prefix = idx ? carried.take(idx) : carried
                "#{Array(s['path']).join('.')} (prefix: #{prefix.inspect})"
              end.join(", ")
              raise "No prefix-compatible carrier for axis #{axis.inspect}. Required: #{req_prefix.inspect}. Candidates: #{details}"
            end

            # 4) Make a deterministic choice from the compatible candidates.
            chosen = compatible.find { |s| Array(s["path"]).map(&:to_s) == [ax.to_s] } ||
                     compatible.min_by { |s| s["navigation_steps"].count { |step| step["kind"] == "array_loop" } } ||
                     compatible.min_by { |s| Array(s["path"]).map(&:to_s).join("/") }

            mapping[ax] = chosen
          end

          new(mapping, access_plan)
        end

        def initialize(mapping, access_plan)
          @mapping = mapping
          @access  = access_plan
        end

        def carrier_for(axis_sym)
          @mapping.fetch(axis_sym.to_sym)
        end

        def entry_for(axis_sym)
          spec = carrier_for(axis_sym)
          # The `via_path` is the path of the carrier InputSpec itself.
          { axis: axis_sym.to_s, via_path: Array(spec["path"]).map(&:to_s) }
        end

        def to_entries
          @mapping.keys.sort_by(&:to_s).map { |axis| entry_for(axis) }
        end
      end
    end
  end
end