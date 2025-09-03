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
            if i == 0
              # First axis: always access named field from input root (array_field semantics)
              header << %(__each_array__(input, "#{ax}") do |#{var}|\n)
            else
              # Subsequent axes: direct array iteration (array_element semantics)
              parent_var = NameMangler.axis_var(axes[i - 1])
              header << %(#{parent_var}.each_with_index do |#{var}, _idx|\n)
            end
            
            if i < axes.length - 1
              row = NameMangler.row_var_for_depth(i)
              row_vars << row
              header << ("  " * (i + 1)) << "#{row} = []\n"
            end
          end

          cursors_line = "cursors = { " + axes.map { |ax| %("#{ax}"=>#{NameMangler.axis_var(ax)}) }.join(",") + " }"

          [header, "", cursors_line, "out", row_vars]
        end

        # NEW: fused nested loops from reduce_plans using axis-based semantics
        # reduce_plans: array of hashes, each with:
        #   - "axis" (String)
        #   - "via_path" (Array<String>) - ignored, using axis semantics instead
        #   - "result_depth" (Integer) — outer = 0, then 1, ...
        #
        # V2 Chain semantics:
        #   - First axis: array_field access with key from input root
        #   - Subsequent axes: array_element direct iteration without key
        #
        # Returns [header, footer, cursors_line, axis_vars]
        def build_reduce_chain(reduce_plans, scope_axes: [])
          plans = Array(reduce_plans).sort_by { |rp| rp.fetch("result_depth") }
          return ["", "", 'cursors = {}', []] if plans.empty?

          header = +""
          axis_vars = []
          full_axis_order = scope_axes.dup
          
          plans.each_with_index do |rp, i|
            axis = rp.fetch("axis").to_s
            full_axis_order << axis
            var = NameMangler.axis_var(axis)
            axis_vars << var
            
            # Determine source expression and access method
            if scope_axes.include?(axis)
              # This axis is already open from site loops, skip loop generation
              next
            end
            
            current_depth = scope_axes.length + i
            if current_depth == 0
              # First axis: access named field from input root
              source_expr = "input"
              key = axis  # Use axis name as field key
            else
              # Subsequent axes: direct array iteration from parent axis variable  
              parent_axis = full_axis_order[current_depth - 1]
              source_expr = NameMangler.axis_var(parent_axis)
              key = nil   # Direct iteration, no key needed
            end
            
            if key
              header << %(__each_array__(#{source_expr}, "#{key}") do |#{var}|\n)
            else
              # Direct array iteration - modify __each_array__ to handle nil key
              header << %(#{source_expr}.each_with_index do |#{var}, _idx|\n)
            end
          end

          # Build cursors for both site axes and reduce axes
          site_cursors = scope_axes.map { |ax| %("#{ax}"=>#{NameMangler.axis_var(ax)}) }
          reduce_cursors = axis_vars.map.with_index { |var, i| 
            axis = plans[i]["axis"].to_s
            next if scope_axes.include?(axis)
            %("#{axis}"=>#{var})
          }.compact
          all_cursors = site_cursors + reduce_cursors
          cursors_line = "cursors = { " + all_cursors.join(",") + " }"

          footer = +""
          active_loops = axis_vars.count { |var| var } # Count non-skipped loops
          (active_loops - 1).downto(0) do |i|
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