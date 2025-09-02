# frozen_string_literal: true

require_relative "name_mangler"

module Kumi
  module Codegen
    module RubyV2
      module LoopBuilder
        module_function

        def build_nested_loops(axes)
          return ["", "", 'cursors = {}', "result", []] if axes.empty?

          header = +"out = []\n"
          row_vars = []

          axes.each_with_index do |ax, i|
            var = NameMangler.axis_var(ax)
            src = i.zero? ? "input" : NameMangler.axis_var(axes[i - 1])
            header << %(__each_array__(#{src}, "#{ax}") do |#{var}|\n)
            if i < axes.length - 1
              row = NameMangler.row_var_for_depth(i)
              row_vars << row
              header << ("  " * (i + 1)) << "#{row} = []\n"
            end
          end

          cursors_line = "cursors = { " + axes.map { |ax| %("#{ax}"=>#{NameMangler.axis_var(ax)}) }.join(",") + " }"

          footer = +""
          (axes.length - 1).downto(0) do |i|
            indent = "  " * (i + 1)
            if i.zero?
              footer << indent << "out << #{row_vars[0]}\n" if row_vars[0]
            elsif i < axes.length - 1
              footer << indent << "#{row_vars[i - 1]} << #{row_vars[i]}\n"
            end
            footer << ("  " * i) << "end\n"
          end

          [header, footer, cursors_line, "out", row_vars]
        end

        # NEW: fused nested loops from reduce_plans
        # reduce_plans: array of hashes, each with:
        #   - "axis" (String)
        #   - "via_path" (Array<String>)
        #   - "result_depth" (Integer) — outer = 0, then 1, ...
        #
        # Returns [header, footer, cursors_line, axis_vars]
        #   - header: nested __each_array__(...) do ... openers (no row buffers)
        #   - footer: matching "end"s
        #   - cursors_line: single innermost line building full cursors hash
        #   - axis_vars: ordered axis var names (outer→inner), e.g., ["a_cube","a_layer","a_row"]
        def build_reduce_chain(reduce_plans)
          plans = Array(reduce_plans).sort_by { |rp| rp.fetch("result_depth") }
          return ["", "", 'cursors = {}', []] if plans.empty?

          header = +""
          axis_vars = []
          axis_order = []
          plans.each_with_index do |rp, i|
            axis = rp.fetch("axis").to_s
            via  = Array(rp.fetch("via_path")).map(&:to_s)
            axis_order << axis
            var = NameMangler.axis_var(axis)
            axis_vars << var

            base_expr, key = base_and_key_for_via(via, axis_order)
            header << %(__each_array__(#{base_expr}, "#{key}") do |#{var}|\n)
          end

          cursors_line = "cursors = { " + axis_order.zip(axis_vars).map { |ax, var| %("#{ax}"=>#{var}) }.join(",") + " }"

          footer = +""
          (plans.length - 1).downto(0) do |i|
            footer << ("  " * i) << "end\n"
          end

          [header, footer, cursors_line, axis_vars]
        end

        # Helper: choose container expr and iter key from via_path
        #
        # Rules (deterministic, no inference):
        #  - via = ["x"]              => base: "input",        key: "x"
        #  - via = ["a","b"]          => base: a_<a>,          key: "b"
        #  - via = ["a","b","c"]      => base: a_<b>,          key: "c"
        #  - via = ["a","b","c","d"]  => base: a_<c>,          key: "d"
        #
        # axis_order is the list of axes opened so far (outer→inner).
        def base_and_key_for_via(via, axis_order)
          case via.length
          when 0 then raise ArgumentError, "empty via_path"
          when 1 then return ["input", via[0]]
          else
            parent_axis = via[-2]
            unless axis_order.include?(parent_axis)
              raise KeyError, "via_path parent axis #{parent_axis.inspect} not yet opened; axis_order=#{axis_order.inspect}"
            end
            return [NameMangler.axis_var(parent_axis), via[-1]]
          end
        end
      end
    end
  end
end