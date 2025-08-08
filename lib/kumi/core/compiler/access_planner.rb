# frozen_string_literal: true

module Kumi
  module Core
    module Compiler
      class AccessPlanner
        # AccessPlan structure:
        # {
        #   path: "regions.offices.revenue",            # dot-separated path string (leaf-inclusive)
        #   containers: [:regions, :offices],           # container lineage (no leaf)
        #   leaf: :revenue,                             # final field
        #   scope: [:regions, :offices],                # alias of containers (for analyzer symmetry)
        #   depth: 2,                                   # number of array nesting levels (containers length)
        #   mode: :each_indexed | :object               # access pattern
        #         | :materialize | :ravel
        #   on_missing: :nil | :skip | :error,          # missing data policy  (TODO: enforce in builder)
        #   key_policy: :indifferent,                   # string/symbol key handling
        #   operations: [
        #     { type: :enter_hash,  key: "regions", on_missing:, key_policy: },
        #     { type: :enter_array, on_missing: },
        #     { type: :enter_hash,  key: "offices", ... },
        #     { type: :enter_array, on_missing: },
        #     { type: :enter_hash,  key: "revenue", ... }
        #   ]
        # }
        #
        # NOTES:
        # - :each_indexed yields (value, index_path) at leaf level;
        # - :ravel flattens only the leaf level, returning a single array for each container
        # - :materialize returns a nested array structure, preserving all containers
        # - :object the value of the input hash key provided only, no array access
        # - Planner is *input-only*. Broadcasting/join/reduce live in analyzer/compiler.

        # Public API
        def self.plan(input_metadata, options = {})
          new(input_metadata, options).plan
        end

        def self.plan_for(input_metadata, path, options = {})
          new(input_metadata, options).plan_for(path)
        end

        def initialize(input_metadata, options = {})
          @input_metadata = input_metadata
          @default_options = {
            on_missing: :error,
            key_policy: :indifferent,
            mode: :nil # default when plan_for(path) is used without explicit mode
          }.merge(options)
          @plans = {}
        end

        # Create plans for *all* leaf paths; emits multiple modes per path.
        # @return [Hash<String, AccessPlan>] "path:mode" -> plan (frozen)
        def plan
          @input_metadata.each do |field_name, field_meta|
            plan_field_access(field_name, field_meta, [field_name.to_s])
          end
          @plans.freeze
        end

        # Create plans for a specific path. If :mode not provided, emit all sensible modes.
        # @return [Hash<String, AccessPlan>] "path:mode" -> plan
        def plan_for(path)
          path_segments = path.split(".")
          field_meta = dig_meta(@input_metadata, path_segments)
          raise ArgumentError, "Unknown path: #{path}" unless field_meta

          emit_plans_for_segments(path_segments, field_meta, explicit_mode: @default_options[:mode])
          @plans.select { |k, _| k.start_with?("#{path}:") }
        end

        private

        # ---- Planning traversal ---------------------------------------------

        def plan_field_access(_field_name, field_meta, current_path)
          # If current node has children, descend until leaves, but also emit a plan
          # at every node so callers can fetch structured containers if they want.
          emit_plans_for_segments(current_path, field_meta)

          return unless children = field_meta[:children]

          children.each do |child_name, child_meta|
            child_path = current_path + [child_name.to_s]
            plan_field_access(child_name, child_meta, child_path)
          end
        end

        def emit_plans_for_segments(path_segments, field_meta, explicit_mode: nil)
          plan = build_base_plan(path_segments, field_meta)

          # Decide which modes to expose for this path
          modes = if explicit_mode
                    [explicit_mode]
                  else
                    infer_modes_for(plan)
                  end

          modes.each do |m|
            @plans["#{plan[:path]}"] ||= []
            @plans["#{plan[:path]}"] << plan.merge(mode: m).freeze
          end
        end

        # ---- Plan building ---------------------------------------------------

        def build_base_plan(path_segments, field_meta)
          containers = extract_container_lineage(path_segments)
          {
            path: path_segments.join("."),
            containers: containers,
            leaf: path_segments.last.to_sym,
            scope: containers.dup, # alias for symmetry with analyzer
            depth: containers.length,
            mode: determine_default_mode(containers.length),
            on_missing: @default_options[:on_missing],
            key_policy: @default_options[:key_policy],
            operations: build_operations(path_segments)
          }.freeze
        end

        # Containers only (array segments), based on metadata traversal.
        def extract_container_lineage(path_segments)
          lineage = []
          current_meta = @input_metadata

          path_segments.each do |segment|
            meta = indifferent_get(current_meta, segment)
            break unless meta

            lineage << segment.to_sym if meta[:type] == :array
            current_meta = meta[:children] || {}
          end
          lineage
        end

        # Choose which modes to emit for a given base plan.
        def infer_modes_for(plan)
          d = plan[:depth]
          if d == 0
            [:object] # no arrays: direct hash access (builder should just fetch the leaf)
          else
            # Always provide:
            %i[each_indexed ravel materialize]
          end
        end

        # Fallback default if caller queried a path without explicit mode.
        def determine_default_mode(depth)
          case depth
          when 0 then :object
          when 1 then :each_indexed
          else :materialize
          end
        end

        # Build low-level navigation ops; builder interprets these.
        def build_operations(path_segments)
          ops = []
          current_children_meta = @input_metadata
          path_segments.each do |segment|
            # Always enter hash by key
            ops << {
              type: :enter_hash,
              key: segment.to_s, # keep string; builder applies key_policy
              on_missing: @default_options[:on_missing],
              key_policy: @default_options[:key_policy]
            }

            meta = indifferent_get(current_children_meta, segment)
            break unless meta

            # If array, enter array context
            ops << { type: :enter_array, on_missing: @default_options[:on_missing] } if meta[:type] == :array

            current_children_meta = meta[:children] || {}
          end
          ops
        end

        # ---- Metadata helpers -----------------------------------------------

        # Indifferent key lookup for metadata (handles symbol/string keys).
        def indifferent_get(hash, key)
          return nil unless hash

          hash[key] || hash[key.to_sym] || hash[key.to_s]
        end

        # Walk metadata to the final node, with indifferent keys.
        def dig_meta(meta, path_segments)
          cur = meta
          path_segments.each do |seg|
            cur = indifferent_get(cur, seg)
            return nil unless cur

            cur = cur # keep as-is; children handled in callers
          end
          cur
        end
      end
    end
  end
end
