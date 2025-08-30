# frozen_string_literal: true

require_relative "../analyzer/structs/input_meta"
require_relative "../analyzer/structs/access_plan"

module Kumi
  module Core
    module Compiler
      # Canonical deterministic access planner (V2)
      #
      # Emits exactly ONE plan per input path. Each plan has a minimal chain:
      #   - array_field   { key, axis }    # object/root → array-valued field
      #   - array_element { alias, axis }  # array → alias step (pure nested arrays)
      #   - field_leaf    { key }          # read a key on an object (any depth)
      #   - element_leaf                    # element itself is the leaf (array of scalars)
      #
      # Array-parent disambiguation:
      #   array parent + child.container == :array:
      #     - alias? if enter_via == :array OR consume_alias == true → array_element
      #     - else (true array field on element object)              → array_field
      #
      #   array parent + child.container != :array:
      #     - if enter_via == :array (alias to scalar)               → terminal handled by element_leaf
      #     - else (field on element object)                         → field_leaf
      #
      # Terminal:
      #   If terminal.container == :scalar and we did NOT just emit field_leaf,
      #   append element_leaf (arrays-of-scalars).
      class AccessPlannerV2
        def self.plan(meta, options = {}) = new(meta, options).plan
        def self.plan_for(meta, path, options = {}) = new(meta, options).plan_for(path)

        def initialize(meta, options = {})
          @meta = meta
          @defaults = { on_missing: :error, key_policy: :indifferent }.merge(options)
          @plans = {}
        end

        def plan
          @meta.each_key { |root| walk_and_emit([root.to_s]) }
          @plans
        end

        def plan_for(path)
          segs = path.is_a?(Array) ? path.map(&:to_s) : path.to_s.split(".")
          ensure_path!(segs)
          emit_for_segments(segs)
          @plans
        end

        private

        # ------------ small predicates (readability) ------------
        def array_parent?(parent_container) = parent_container == :array
        def objectish_parent?(parent_container) = [:object, :hash, :read, nil].include?(parent_container)

        # Is an array child under an array parent an alias step?
        # Prefer enter_via==:array; allow consume_alias to force alias even if enter_via says :hash (defensive).
        def alias_step?(child_node, parent_container)
          return false unless array_parent?(parent_container)
          child_node[:container] == :array && (child_node[:enter_via] == :array || child_node[:consume_alias] == true)
        end

        # True array field on element object (array parent → hash field that is itself an array)
        def array_field_under_array?(child_node, parent_container)
          array_parent?(parent_container) &&
            child_node[:container] == :array &&
            child_node[:enter_via] != :array &&
            child_node[:consume_alias] != true
        end

        def walk_and_emit(path_segments)
          emit_for_segments(path_segments)
          node = meta_node_for(path_segments)
          return if node[:children].nil?
          node[:children].each_key { |c| walk_and_emit(path_segments + [c.to_s]) }
        end

        def emit_for_segments(path_segments)
          lineage_axes = container_lineage(path_segments) # symbols for array segments
          base = {
            path: path_segments.join("."),
            containers: lineage_axes,
            leaf: path_segments.last.to_sym,
            scope: lineage_axes.dup,
            depth: lineage_axes.length,
            on_missing: @defaults[:on_missing],
            key_policy: @defaults[:key_policy]
          }

          built = build_chain(path_segments, lineage_axes)
          plan  = Kumi::Core::Analyzer::Structs::AccessPlan.new(
            path: base[:path],
            containers: base[:containers],
            leaf: base[:leaf],
            scope: base[:scope],
            depth: base[:depth],
            mode: :read,
            on_missing: base[:on_missing],
            key_policy: base[:key_policy],
            operations: built[:operations],
            chain: built[:chain]
          )

          (@plans[base[:path]] ||= []) << plan
        end

        def build_chain(path_segments, lineage_axes)
          chain = []
          ops   = [] # legacy/no-op

          cur_meta = @meta
          parent   = nil
          axis_idx = 0
          last_was_field_leaf = false

          path_segments.each_with_index do |seg, i|
            node = fetch!(cur_meta, seg, path_segments)

            parent_container = parent&.[](:container) || :object
            child_container  = node[:container] or raise_contract!(":container", seg, path_segments)
            enter_via        = i.zero? ? :hash : (node[:enter_via] or raise_contract!(":enter_via", seg, path_segments))

            if objectish_parent?(parent_container)
              if child_container == :array
                axis = lineage_axes[axis_idx] or raise "axis underflow at #{path_segments.join('.')}"
                chain << { "kind" => "array_field", "key" => seg, "axis" => axis.to_s }
                ops   << { type: :enter_hash, key: seg }
                axis_idx += 1
                last_was_field_leaf = false
              else
                chain << { "kind" => "field_leaf", "key" => seg }
                ops   << { type: :enter_hash, key: seg }
                last_was_field_leaf = true
              end

            elsif array_parent?(parent_container)
              case child_container
              when :array
                if alias_step?(node, parent_container)
                  axis = lineage_axes[axis_idx] or raise "axis underflow at #{path_segments.join('.')}"
                  chain << { "kind" => "array_element", "alias" => seg, "axis" => axis.to_s }
                  ops   << { type: :enter_array }
                  axis_idx += 1
                  last_was_field_leaf = false
                elsif array_field_under_array?(node, parent_container)
                  axis = lineage_axes[axis_idx] or raise "axis underflow at #{path_segments.join('.')}"
                  chain << { "kind" => "array_field", "key" => seg, "axis" => axis.to_s }
                  ops   << { type: :enter_hash, key: seg }
                  axis_idx += 1
                  last_was_field_leaf = false
                else
                  # Defensive default: prefer alias_step semantics
                  axis = lineage_axes[axis_idx] or raise "axis underflow at #{path_segments.join('.')}"
                  chain << { "kind" => "array_element", "alias" => seg, "axis" => axis.to_s }
                  ops   << { type: :enter_array }
                  axis_idx += 1
                  last_was_field_leaf = false
                end

              when :scalar
                if enter_via == :array || node[:consume_alias] == true
                  # Scalar via alias: terminal handled by element_leaf at the end
                  last_was_field_leaf = false
                else
                  # Scalar field on the element object
                  chain << { "kind" => "field_leaf", "key" => seg }
                  last_was_field_leaf = true
                end

              else
                # :object / :hash etc. → a regular field on the element
                chain << { "kind" => "field_leaf", "key" => seg }
                last_was_field_leaf = true
              end

            else
              raise "Invalid parent container #{parent_container.inspect} at #{path_segments.join('.')}"
            end

            parent   = node
            cur_meta = node[:children] || {}
          end

          # terminal: arrays-of-scalars only (avoid after a field read)
          chain << { "kind" => "element_leaf" } if parent && parent[:container] == :scalar && !last_was_field_leaf

          { chain: chain, operations: ops }
        end

        # lineage axes = segments where node.container == :array
        def container_lineage(path_segments)
          axes = []
          cur  = @meta
          path_segments.each do |seg|
            node = fetch!(cur, seg, path_segments)
            axes << seg.to_sym if node[:container] == :array
            cur = node[:children] || {}
          end
          axes
        end

        def meta_node_for(path_segments)
          cur = @meta
          last = nil
          path_segments.each do |seg|
            last = fetch!(cur, seg, path_segments)
            cur  = last[:children] || {}
          end
          last
        end

        def ensure_path!(path_segments)
          meta_node_for(path_segments) or raise ArgumentError, "Unknown path: #{path_segments.join('.')}"
        end

        def fetch!(h, k, full_path)
          h[k.to_sym] or raise ArgumentError,
                               "Missing metadata for '#{k}' in #{full_path.join('.')}. Available keys: #{h.keys.inspect}"
        end

        def raise_contract!(field, seg, full_path)
          raise ArgumentError, "Metadata contract violation: missing #{field} for segment '#{seg}' in '#{full_path.join('.')}'"
        end
      end
    end
  end
end
