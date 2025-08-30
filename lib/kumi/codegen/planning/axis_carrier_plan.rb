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
      #   #len_call(axis, idx_var: "idx", data_var: "data") -> String (codegen helper)
      class AxisCarrierPlan
        def self.build(decl_axes:, access_plan:)
          mapping = {}
          decl_axes.each do |a|
            candidates = access_plan.carriers_for_axis(a)
            raise "No input path carries axis #{a.inspect}" if candidates.empty?

            # Deterministic choice: 1) exact path == [a], else 2) shortest chain length, else 3) first by path name
            chosen =
              candidates.find { |s| s.path.map(&:to_s) == [a.to_s] } ||
              candidates.min_by { |s| s.chain.length } ||
              candidates.sort_by { |s| s.path.map(&:to_s).join("/") }.first

            mapping[a.to_sym] = chosen
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

        # Codegen-facing helper (string) — you may ignore if you construct calls elsewhere
        def len_call(axis_sym, data_var: "@d", idx_var: "idx")
          spec = carrier_for(axis_sym)
          method = @access.axis_len_method_name(axis_sym, spec.path)
          "#{method}(#{data_var}, #{idx_var})"
        end
      end
    end
  end
end
