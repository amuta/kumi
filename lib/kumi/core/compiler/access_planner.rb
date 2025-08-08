module Kumi
  module Core
    module Compiler
      # AccessPlanner is responsible for generating access plans for the given input metadata.
      # It traverses the metadata structure and builds a plan that describes how to access
      # the data at various levels, including handling arrays, hashes, and different access modes.
      #
      # The generated plans are used by the Kumi compiler to optimize data access patterns.
      #
      # Example usage:
      #   plan = AccessPlanner.plan(input_metadata)
      #   plan_for_revenue = AccessPlanner.plan_for(input_metadata, "regions.offices.revenue")
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
          @meta = input_metadata
          @defaults = {
            on_missing: :error,
            key_policy: :indifferent,
            mode: nil
          }.merge(options)
          @plans = {}
        end

        def plan
          @meta.each_key { |root| walk_and_emit([root.to_s]) }
          @plans.freeze
        end

        def plan_for(path)
          segs = path.split(".")
          ensure_path!(segs)
          emit_for_segments(segs, explicit_mode: @defaults[:mode])
          @plans.select { |k, _| k.start_with?("#{path}:") }
        end

        private

        def walk_and_emit(path_segs)
          emit_for_segments(path_segs)
          node = meta_node_for(path_segs)
          return unless children = node&.[](:children)

          children.each_key { |child| walk_and_emit(path_segs + [child.to_s]) }
        end

        def emit_for_segments(path_segs, explicit_mode: nil)
          plan = build_base_plan(path_segs)
          modes = explicit_mode ? [explicit_mode] : infer_modes(plan)
          modes.each do |m|
            (@plans[plan[:path]] ||= []) << plan.merge(mode: m).freeze
          end
        end

        def build_base_plan(path_segs)
          lineage = container_lineage(path_segs)
          {
            path: path_segs.join("."),
            containers: lineage,
            leaf: path_segs.last.to_sym,
            scope: lineage.dup,
            depth: lineage.length,
            mode: default_mode_for_depth(lineage.length),
            on_missing: @defaults[:on_missing],
            key_policy: @defaults[:key_policy],
            operations: build_operations(path_segs)
          }.freeze
        end

        def infer_modes(plan)
          plan[:depth].zero? ? [:object] : %i[each_indexed ravel materialize]
        end

        def default_mode_for_depth(d)
          return :object       if d == 0
          return :each_indexed if d == 1

          :materialize
        end

        def build_operations(path_segs)
          ops = []
          parent_meta    = nil
          current_childs = @meta

          path_segs.each do |seg|
            seg_meta = indifferent_get(current_childs, seg) or
              raise ArgumentError, "Unknown segment '#{seg}' in '#{path_segs.join('.')}'"

            ops << enter_hash(seg) if should_enter_hash?(parent_meta, seg_meta)
            ops << enter_array     if should_enter_array?(parent_meta, seg_meta)

            current_childs = seg_meta[:children] || {}
            parent_meta    = seg_meta
          end

          ops
        end

        def should_enter_hash?(parent_meta, seg_meta)
          return true  if parent_meta.nil?                 # root hop
          return false if element_array?(parent_meta)      # child label after element-mode is synthetic
          return false if element_array?(seg_meta)         # element-mode label itself isn’t a key

          true
        end

        def should_enter_array?(parent_meta, seg_meta)
          return false unless array?(seg_meta)
          return false if element_array?(parent_meta)      # already at that child array

          true
        end

        def array?(m)         = m && m[:type] == :array
        def element_array?(m) = array?(m) && (m[:access_mode] || :object) == :element

        def enter_hash(key)
          { type: :enter_hash, key: key.to_s,
            on_missing: @defaults[:on_missing],
            key_policy: @defaults[:key_policy] }
        end

        def enter_array
          { type: :enter_array, on_missing: @defaults[:on_missing] }
        end

        def container_lineage(path_segs)
          lineage        = []
          parent_meta    = nil
          current_childs = @meta

          path_segs.each do |seg|
            seg_meta = indifferent_get(current_childs, seg)
            # skip counting the synthetic seg after an element-array
            lineage << seg.to_sym if array?(seg_meta)
            current_childs = seg_meta&.[](:children) || {}
            parent_meta    = seg_meta
          end

          # If the final hop was synthetic (parent element-array, leaf scalar),
          # lineage is still correct: we never counted the synthetic seg anyway.
          lineage
        end

        def meta_node_for(path_segs)
          cur_children = @meta
          last_meta    = nil
          path_segs.each do |seg|
            seg_meta = indifferent_get(cur_children, seg)
            return nil unless seg_meta

            last_meta    = seg_meta
            cur_children = seg_meta[:children] || {}
          end
          last_meta
        end

        def ensure_path!(path_segs)
          raise ArgumentError, "Unknown path: #{path_segs.join('.')}" unless meta_node_for(path_segs)
        end

        def indifferent_get(hash, key)
          return nil unless hash

          hash[key] || hash[key.to_sym] || hash[key.to_s]
        end
      end
    end
  end
end
