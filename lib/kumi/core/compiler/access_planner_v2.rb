# frozen_string_literal: true

module Kumi
  module Core
    module Compiler
      class AccessPlannerV2
        attr_reader :plans, :index_table

        DEFAULTS = { on_missing: :error, key_policy: :indifferent }.freeze
        def self.plan(meta, options = {}, debug_on: false) = new(meta, options, debug_on:).plan

        def initialize(meta, options = {}, debug_on: false)
          @meta         = meta
          @debug_on     = debug_on
          @defaults     = DEFAULTS.merge(options.transform_keys(&:to_sym))
          @plans        = []
          @index_table  = {}
        end

        def plan
          @meta.each do |root_name, node|
            # Synthetic hop: implicit root hash → reach declared root by key
            steps = [{ kind: :property_access, key: root_name.to_s }]
            axes  = []

            # If the root itself is an array, open its loop at the root axis
            if node.container == :array
              steps << { kind: :array_loop, axis: root_name.to_s }
              axes  << root_name.to_sym
            end

            # Emit normal plan for the root node # The root axes are always [], e.g. array :x (the container :x opens [:x], but is not inside that dim)
            walk([root_name.to_s], node, steps, axes, steps, [])

            # If the root array defines an index, emit a *synthetic* index plan now
            next unless node.container == :array && node.define_index

            emit_index_plan!(
              idx_name: node.define_index,
              fqn_prefix: root_name.to_s,
              axes: axes.dup,
              steps: steps.dup
            )
          end

          @plans.sort_by! { |p| p.path_fqn }
          self
        end

        private

        def debug(msg)
          return unless @debug_on

          puts msg
        end

        def walk(path_segs, node, steps_so_far, axes_so_far, node_steps = nil, node_axes = nil)
          fqn   = path_segs.join(".")
          axes  = node_axes || axes_so_far
          steps = node_steps || steps_so_far

          axes_str   = "[#{axes.join(', ')}]"
          steps_desc = steps.map do |s|
            case s[:kind]
            when :property_access then ".#{s[:key]}"
            when :element_access  then "[]"
            when :array_loop      then "loop(#{s[:axis]})"
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
            path_fqn: fqn,
            open_axis: axes.size < axes_so_far.size
          )

          return unless node.children && !node.children.empty?

          node.children.each do |cname, child|
            edge_steps = node.child_steps.fetch(cname.to_sym)
            edge_desc  = edge_steps.map { |s| s[:kind] == :array_loop ? "loop(#{s[:axis]})" : s[:kind].to_s.split("_").first }.join(" → ")
            debug "   ↳ #{cname}: #{edge_desc}"

            new_steps = steps_so_far + edge_steps
            new_axes  = axes_so_far.dup
            new_axes << cname.to_sym if edge_steps.any? { |s| (s[:kind] || s["kind"]) == :array_loop }

            # If the child is an array with a declared index, emit its synthetic index plan
            if child.container == :array && child.define_index
              emit_index_plan!(
                idx_name: child.define_index,
                fqn_prefix: "#{fqn}.#{cname}",
                axes: new_axes.dup,
                steps: new_steps.dup
              )
            end

            # OVERRIDE: for array containers, the container node itself is *not* in the child axis.
            child_node_axes  = nil
            child_node_steps = nil
            if edge_steps.last && edge_steps.last[:kind] == :array_loop &&
               edge_steps.last[:axis].to_s == cname.to_s &&
               child.container == :array
              child_node_axes  = new_axes[0...-1]
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

        # --- Synthetic index plan emitter ---
        #
        # For an axis index declared on an array node, we create a synthetic path:
        #   "#{fqn_prefix}.__index(<name>)"
        # Its steps mirror "being at the element" of that loop, so we append an :element_access.
        # Axes are exactly the axes of the array *element* (i.e., including this axis).
        #
        def emit_index_plan!(idx_name:, fqn_prefix:, axes:, steps:)
          idx_fqn   = "#{fqn_prefix}.__index(#{idx_name})"
          idx_steps = steps + [{ kind: :element_access }]

          debug "   [index] #{idx_name} → #{idx_fqn}"
          debug "           axes: [#{axes.join(', ')}]"
          debug "           steps: #{idx_steps.map do |s|
            case s[:kind]
            when :property_access then ".#{s[:key]}"
            when :element_access  then '[]'
            when :array_loop      then "loop(#{s[:axis]})"
            end
          end.join(' ')}"

          @plans << Core::Analyzer::Plans::InputPlan.new(
            source_path: [],               # synthetic (not an actual declared field path)
            axes: axes,
            dtype: :integer,               # indices are integers
            key_policy: @defaults[:key_policy],
            missing_policy: @defaults[:on_missing],
            navigation_steps: idx_steps,
            path_fqn: idx_fqn
          )

          @index_table[idx_name] = { axes: axes, fqn: idx_fqn }
        end
      end
    end
  end
end
