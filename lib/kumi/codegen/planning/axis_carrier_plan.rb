# frozen_string_literal: true

module Kumi
  module Codegen
    module Planning
      # AxisCarrierPlan picks ONE authoritative input path as the "carrier"
      # of length for each declaration axis (bounds only; NOT used for reads).
      #
      # Uses axis_loops directly (each loop has :axis, :path, :loop_idx, ...).
      #
      # Interface:
      #   .build(decl_axes:, access_plan:) -> AxisCarrierPlan
      #   #carrier_for(axis) -> InputSpec
      class AxisCarrierPlan
        def self.build(decl_axes:, access_plan:, required_prefix: [])
          mapping = {}

          decl_axes.each do |axis|
            ax = axis.to_sym

            # 1) candidates: inputs that carry this axis
            candidates = access_plan.inputs_by_path.values.select do |spec|
              spec.axis_loops.any? { |lp| (lp[:axis] || lp["axis"]).to_sym == ax }
            end
            raise "No input path carries axis #{axis.inspect}" if candidates.empty?

            # 2) required prefix at this site
            req_prefix = (required_prefix + decl_axes.take_while { |a| a != axis }).map!(&:to_sym)

            # 3) filter by prefix-compatibility
            compatible = candidates.select do |spec|
              loops = spec.axis_loops
              loop_for_ax = loops.find { |lp| (lp[:axis] || lp["axis"]).to_sym == ax }
              depth = loops.index(loop_for_ax) || 0
              actual_prefix = loops.take(depth).map { |lp| (lp[:axis] || lp["axis"]).to_sym }
              actual_prefix == req_prefix
            end

            if compatible.empty?
              details = candidates.map do |s|
                carried = s.axis_loops.map { |lp| (lp[:axis] || lp["axis"]).to_sym }
                idx = carried.index(ax)
                prefix = idx ? carried.take(idx) : carried
                "#{Array(s.path).join('.')} (prefix: #{prefix.inspect})"
              end.join(", ")
              raise "No prefix-compatible carrier for axis #{axis.inspect}. " \
                    "Required: #{req_prefix.inspect}. Candidates: #{details}"
            end

            # 4) deterministic pick
            chosen = compatible.find { |s| Array(s.path).map(&:to_s) == [ax.to_s] } ||
                     compatible.min_by { |s| s.axis_loops.length } ||
                     compatible.min_by { |s| Array(s.path).map(&:to_s).join("/") }

            mapping[ax] = chosen
          end

          new(mapping, access_plan)
        end

        def initialize(mapping, access_plan)
          @mapping = mapping # { axis(Symbol) => InputSpec }
          @access  = access_plan
        end

        def carrier_for(axis_sym) = @mapping.fetch(axis_sym.to_sym)

        def entry_for(axis_sym)
          spec = carrier_for(axis_sym)
          { axis: axis_sym.to_sym, via_path: Array(spec.path).map(&:to_s) }
        end

        def to_entries
          @mapping.keys.sort_by(&:to_s).map { |axis| entry_for(axis) }
        end
      end
    end
  end
end
