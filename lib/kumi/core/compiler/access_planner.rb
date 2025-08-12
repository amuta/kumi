# frozen_string_literal: true

require_relative "../analyzer/structs/input_meta"
require_relative "../analyzer/structs/access_plan"

module Kumi
  module Core
    module Compiler
      # Generates deterministic access plans from normalized input metadata.
      #
      # Metadata expectations (produced by InputCollector):
      # - Each node has:
      #     :container   => :scalar | :read | :array
      #     :children    => { name => meta }  (optional)
      # - Each non-root node (i.e., any child) carries edge hints from its parent:
      #     :enter_via     => :field | :array   # how the parent reaches THIS node
      #     :consume_alias => true|false        # inline array edge; planner does not need this to emit ops
      #
      # Planning rules (single source of truth):
      # - Root is an implicit object.
      # - If parent is :array, always emit :enter_array before stepping to the child.
      #     - If child.enter_via == :field → also emit :enter_hash(child_name).
      #     - If child.enter_via == :array → inline edge, do NOT emit :enter_hash for the alias.
      # - If parent is :read (or root), emit :enter_hash(child_name).
      #
      # Modes (one plan per mode):
      # - Scalar paths (no array in lineage)    → [:read]
      # - Vector paths (≥1 array in lineage)    → [:each_indexed, :materialize, :ravel]
      # - If @defaults[:mode] is set, emit only that mode (alias :read → :read).
      class AccessPlanner
        def self.plan(meta, options = {}) = new(meta, options).plan
        def self.plan_for(meta, path, options = {}) = new(meta, options).plan_for(path)

        def initialize(meta, options = {})
          @meta = meta
          @defaults = { on_missing: :error, key_policy: :indifferent, mode: nil }.merge(options)
          @plans = {}
        end

        def plan
          @meta.each_key { |root| walk_and_emit([root.to_s]) }
          @plans
        end

        def plan_for(path)
          segs = path.split(".")
          ensure_path!(segs)
          emit_for_segments(segs, explicit_mode: @defaults[:mode])
          @plans
        end

        private

        def walk_and_emit(path)
          emit_for_segments(path)
          node = meta_node_for(path)
          return if node[:children].nil?

          node[:children].each_key do |c|
            walk_and_emit(path + [c.to_s])
          end
        end

        def emit_for_segments(path, explicit_mode: nil)
          lineage = container_lineage(path)
          base    = build_base_plan(path, lineage)
          node    = meta_node_for(path)

          modes = explicit_mode || infer_modes(lineage, node)
          modes = [modes] unless modes.is_a?(Array)

          list = (@plans[base[:path]] ||= [])
          modes.each do |mode|
            operations = build_operations(path, mode)

            list << Kumi::Core::Analyzer::AccessPlan.new(
              path: base[:path],
              containers: base[:containers],
              leaf: base[:leaf],
              scope: base[:scope],
              depth: base[:depth],
              mode: mode, # :read | :each_indexed | :materialize | :ravel
              on_missing: base[:on_missing],
              key_policy: base[:key_policy],
              operations: operations
            )
          end
        end

        def build_base_plan(path, lineage)
          {
            path: path.join("."),
            containers: lineage, # symbols of array segments in the path
            leaf: path.last.to_sym,
            scope: lineage.dup,            # alias kept for analyzer symmetry
            depth: lineage.length,         # rank
            on_missing: @defaults[:on_missing],
            key_policy: @defaults[:key_policy]

          }.freeze
        end

        def infer_modes(lineage, _node)
          lineage.empty? ? [:read] : %i[each_indexed materialize ravel]
        end

        # Core op builder: apply the parent→child edge rule per segment.
        def build_operations(path, mode)
          ops = []
          parent_meta = nil
          cur = @meta

          puts "\n🔨 Building operations for path: #{path.join('.')}:#{mode}" if ENV["DEBUG_ACCESSOR_OPS"]

          path.each_with_index do |seg, idx|
            node = ig(cur, seg) or raise ArgumentError, "Unknown segment '#{seg}' in '#{path.join('.')}'"

            puts "  Segment #{idx}: '#{seg}'" if ENV["DEBUG_ACCESSOR_OPS"]

            # Validate required fields before using them
            container = parent_meta&.[](:container)
            enter_via = if is_root_segment?(idx)
                          nil
                        else
                          node[:enter_via] do
                            raise ArgumentError,
                                  "Missing :enter_via for non-root segment '#{seg}' at '#{path.join('.')}'. Contract violation."
                          end
                        end

            if container == :array
              # Array parent: always step into elements first
              ops << enter_array
              puts "      Added: enter_array" if ENV["DEBUG_ACCESSOR_OPS"]

              # Then either inline (no hash) or field hop to named member
              if enter_via == :hash
                ops << enter_hash(seg)
                puts "      Added: enter_hash('#{seg}')" if ENV["DEBUG_ACCESSOR_OPS"]
              elsif enter_via == :array
                # Inline alias, no hash operation needed
                puts "      Skipped enter_hash (inline alias)" if ENV["DEBUG_ACCESSOR_OPS"]
              else
                raise ArgumentError, "Invalid :enter_via '#{enter_via}' for array child '#{seg}'. Must be :hash or :array"
              end
            elsif container.nil? || container == :object
              # Root or object parent - always emit enter_hash
              ops << enter_hash(seg)
              puts "      Added: enter_hash('#{seg}')" if ENV["DEBUG_ACCESSOR_OPS"]
            else
              raise ArgumentError, "Invalid parent :container '#{container}' for segment '#{seg}'. Expected :array, :object, or nil (root)"
            end

            parent_meta = node
            cur = node[:children] || {}
          end

          terminal = parent_meta

          if terminal && terminal[:container] == :array
            case mode
            when :each_indexed, :ravel
              ops << enter_array
              # :materialize and :read do not step into elements
            end
          end

          # # If we land on an array and this mode iterates elements, step into it.
          puts "  Final operations: #{ops.inspect}" if ENV["DEBUG_ACCESSOR_OPS"]

          ops
        end

        def container_lineage(path)
          lineage = []
          cur = @meta
          path.each do |seg|
            m = ig(cur, seg)
            container = m[:container] do
              raise ArgumentError, "Missing :container for '#{seg}' in path '#{path.join('.')}'. Contract violation."
            end
            lineage << seg.to_sym if container == :array
            cur = m[:children] || {}
          end
          lineage
        end

        def meta_node_for(path)
          cur = @meta
          last = nil
          path.each do |seg|
            m = ig(cur, seg)
            last = m
            cur = m[:children] || {}
          end
          last
        end

        def ensure_path!(path)
          raise ArgumentError, "Unknown path: #{path.join('.')}" unless meta_node_for(path)
        end

        def ig(h, k)
          h[k.to_sym] or raise ArgumentError, "Missing required field '#{k}' in metadata. Available keys: #{h.keys.inspect}"
        end

        def enter_hash(key)
          { type: :enter_hash, key: key.to_s,
            on_missing: @defaults[:on_missing], key_policy: @defaults[:key_policy] }
        end

        def enter_array
          { type: :enter_array, on_missing: @defaults[:on_missing] }
        end

        def is_root_segment?(idx)
          idx == 0
        end
      end
    end
  end
end
