# frozen_string_literal: true

module Kumi
  module Core
    module Compiler
      class AccessPlannerV2
        DEFAULTS = { on_missing: :error, key_policy: :indifferent }.freeze
        def self.plan(meta, options = {}, debug_on: false) = new(meta, options, debug_on:).plan

        def initialize(meta, options = {}, debug_on: false)
          @meta     = meta
          @debug_on = debug_on
          @defaults = DEFAULTS.merge(options.transform_keys(&:to_sym))
          @plans    = []
        end

        def plan
          @meta.each do |root_name, node|
            # Synthetic hop: implicit root is a hash → reach the declared root by key
            steps = [{ kind: :property_access, key: root_name.to_s }]
            axes  = []

            # If the root itself is an array, we enter its loop at the root axis
            if node.container == :array
              steps << { kind: :array_loop, axis: root_name.to_s }
              axes  << root_name.to_sym
            end

            walk([root_name.to_s], node, steps, axes, steps, axes)
          end
          @plans.sort_by! { |p| p.path_fqn }
        end

        private

        def debug(msg)
          return unless @debug_on

          puts msg
        end

        def walk(path_segs, node, steps_so_far, axes_so_far, node_steps = nil, node_axes = nil)
          fqn = path_segs.join(".")

          axes = node_axes || axes_so_far
          steps = node_steps || steps_so_far

          axes_str = "[#{axes.join(', ')}]"
          steps_desc = steps.map do |s|
            case s[:kind]
            when :property_access then ".#{s[:key]}"
            when :element_access then "[]"
            when :array_loop then "loop(#{s[:axis]})"
            end
          end.join(" ")

          override_marker = node_axes || node_steps ? " [OVERRIDE]" : ""
          debug "#{fqn} | axes: #{axes_str} | dtype: #{node.type}#{override_marker}"
          debug "   steps: #{steps_desc}" unless steps.empty?

          @plans << Core::Analyzer::Plans::InputPlan.new(
            source_path: path_segs.map(&:to_sym),
            axes: axes,
            dtype: node.type,
            key_policy: @defaults[:key_policy],
            missing_policy: @defaults[:on_missing],
            navigation_steps: steps,
            path_fqn: fqn
          )

          return unless node.children && !node.children.empty?

          node.children.each do |cname, child|
            edge_steps = node.child_steps.fetch(cname.to_sym)
            edge_desc = edge_steps.map { |s| s[:kind] == :array_loop ? "loop(#{s[:axis]})" : s[:kind].to_s.split("_").first }.join(" → ")
            debug "   ↳ #{cname}: #{edge_desc}"

            new_steps  = steps_so_far + edge_steps
            new_axes   = axes_so_far.dup

            new_axes  << cname.to_sym if edge_steps.any? { |s| (s[:kind] || s["kind"]) == :array_loop }

            child_node_axes = nil
            child_node_steps = nil
            is_last_arr_loop = edge_steps.last[:kind] == :array_loop
            is_last_axis_child = edge_steps.last[:axis].to_s == cname.to_s
            is_child_array_container = child.container == :array

            if is_last_arr_loop && is_last_axis_child && is_child_array_container
              child_node_axes = new_axes[0...-1]
              child_node_steps = new_steps[0...-1]
              debug "      [OVERRIDE] Array container detected: dropping last axis/step for #{cname}"
              debug "         axes before:  #{new_axes.inspect}"
              debug "         axes after:   #{child_node_axes.inspect}"
              debug "         steps before: #{new_steps.inspect}"
              debug "         steps after:  #{child_node_steps.inspect}"
            end

            walk(path_segs + [cname.to_s], child, new_steps, new_axes, child_node_steps, child_node_axes)
          end
        end
      end
    end
  end
end
