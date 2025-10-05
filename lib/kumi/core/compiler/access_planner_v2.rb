# frozen_string_literal: true

module Kumi
  module Core
    module Compiler
      class AccessPlannerV2
        DEFAULTS = { on_missing: :error, key_policy: :indifferent }.freeze
        def self.plan(meta, options = {}) = new(meta, options).plan

        def initialize(meta, options = {})
          @meta     = meta
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

            walk([root_name.to_s], node, steps, axes)
          end
          @plans.sort_by! { |p| p.path_fqn }
        end

        private

        def walk(path_segs, node, steps_so_far, axes_so_far)
          @plans << Core::Analyzer::Plans::InputPlan.new(
            source_path: path_segs.map(&:to_sym),
            axes: axes_so_far.dup,
            dtype: node.type,
            key_policy: @defaults[:key_policy],
            missing_policy: @defaults[:on_missing],
            navigation_steps: steps_so_far.dup,
            path_fqn: path_segs.join(".")
          )

          return unless node.children && !node.children.empty?

          node.children.each do |cname, child|
            edge_steps = node.child_steps.fetch(cname.to_sym)
            new_steps  = steps_so_far + edge_steps
            new_axes   = axes_so_far.dup
            new_axes  << cname.to_sym if edge_steps.any? { |s| (s[:kind] || s["kind"]) == :array_loop }
            walk(path_segs + [cname.to_s], child, new_steps, new_axes)
          end
        end
      end
    end
  end
end
