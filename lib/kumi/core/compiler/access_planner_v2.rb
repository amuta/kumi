# frozen_string_literal: true

# Chain-free AccessPlannerV2
#
# Produces a canonical **input_table** (Hash keyed by Array<Symbol> paths) with NO chains:
#
#   {
#     [:depts] => {
#       axes:       [:depts],                 # logical axes (scope) consumed by this path (ordered)
#       dtype:      :array|:integer|...,      # terminal dtype for this path
#       axis_loops: [                        # physical loop heads (authoritative for codegen)
#         { axes: :depts, path: [:depts], loop_idx: 0, kind: "array_field",  key: "depts" }
#       ],
#       leaf_nav:   [                        # trailing object field reads after the last loop
#         { "kind" => "field_leaf", "key" => "headcount" }
#       ],
#       terminal:   {                        # terminal read semantics + policies
#         "kind"       => "none" | "element_leaf",   # "element_leaf" only for arrays-of-scalars
#         "dtype"      => "integer",                # echoed for convenience
#         "key_policy" => "indifferent",
#         "on_missing" => "error"
#       },
#       path_fqn:   "depts",                 # fully-qualified path for display/debug
#       key_policy: :indifferent,
#       on_missing: :error
#     },
#     ...
#   }
#
# Notes:
# - **axis_loops** contains only array loop heads (kinds: "array_field" or "array_element").
# - **leaf_nav** contains only `"field_leaf"` steps (never `"element_leaf"`).
# - **terminal.kind** is:
#     - "element_leaf" for arrays-of-scalars (i.e., the element itself is the value, no field read)
#     - "none" otherwise (e.g., when you finished on a field read)
#
module Kumi
  module Core
    module Compiler
      class AccessPlannerV2
        DEFAULTS = { on_missing: :error, key_policy: :indifferent }.freeze

        def self.plan(meta, options = {}) = new(meta, options).plan

        def initialize(meta, options = {})
          @meta     = meta # nodes respond to: :container, :enter_via, :consume_alias, :children, :type
          @defaults = DEFAULTS.merge(options.transform_keys(&:to_sym))
          @table    = {}
        end

        # Build the full input_table
        def plan
          @meta.each_key { |root| walk([root.to_s]) }
          @table
        end

        private

        # ---- tree walk ----
        def walk(path_segs)
          emit_entry(path_segs)
          node = meta_node_for(path_segs)
          return unless node && node.children

          node.children.each_key { |k| walk(path_segs + [k.to_s]) }
        end

        # ---- entry builder (no chains) ----
        def emit_entry(path_segs)
          path_sym = path_segs.map!(&:to_sym)
          path_fqn = path_segs.join(".")
          dtype    = extract_dtype(@meta, path_sym)


          loops, kinds, last_node = compute_axis_loops_and_step_kinds(path_segs)


          # leaf_nav = trailing field reads only (never element_leaf)
          last_loop_idx = kinds.rindex { |sk| sk == :array_field || sk == :array_element } || -1
          leaf_nav = []
          (last_loop_idx + 1).upto(path_segs.length - 1) do |i|
            if kinds[i] == :field_leaf
              leaf_nav << { "kind" => "field_leaf", "key" => path_segs[i].to_s }
            elsif kinds[i] == :element_leaf
              # Don't add to leaf_nav - this is direct element access
            end
          end

          # terminal.kind
          terminal_kind =
            if kinds.last == :element_leaf
              "element_leaf" # arrays-of-scalars → take the element
            elsif last_node && last_node.container == :scalar && kinds.last != :field_leaf
              "element_leaf" # arrays-of-scalars → take the element
            else
              "none"
            end


          entry = {
            axis_loops: loops,
            leaf_nav:   leaf_nav,
            terminal:   {
              "kind"       => terminal_kind,
              "dtype"      => dtype.to_s,
              "key_policy" => @defaults[:key_policy].to_s,
              "on_missing" => @defaults[:on_missing].to_s
            },
            dtype:      dtype,
            axes:       loops.map { |l| l[:axes] }, # logical scope for analyzers
            path_fqn:   path_fqn,
            key_policy: @defaults[:key_policy],
            on_missing: @defaults[:on_missing]
          }

          @table[path_sym] = entry
        end

        # Determine axis_loops and per-segment kinds without building a chain.
        # kinds per segment: :array_field, :array_element, :field_leaf
        #
        # Returns: [loops, kinds, last_node]
        def compute_axis_loops_and_step_kinds(path_segs)
          loops  = []
          kinds  = []
          axes_i = 0

          cur = @meta
          parent = nil
          last_node = nil

          path_segs.each_with_index do |seg, idx|
            node = fetch_node!(cur, seg, path_segs)
            parent_container = (parent&.container || :object)
            child_container  = node.container or raise_contract!(":container", seg, path_segs)
            enter_via        = (idx.zero? ? :hash : (node.enter_via or raise_contract!(":enter_via", seg, path_segs)))


            case parent_container
            when :object, :hash, :read, nil
              if child_container == :array
                loops << {
                  axes:     seg.to_sym,
                  path:     path_segs[0..idx].map(&:to_sym),
                  loop_idx: axes_i,
                  kind:     "array_field",
                  key:      seg.to_s
                }
                kinds << :array_field
                axes_i += 1
              else
                kinds << :field_leaf
              end

            when :array
              if child_container == :array
                if alias_step?(node)
                  loops << {
                    axes:     seg.to_sym,
                    path:     path_segs[0..idx].map(&:to_sym),
                    loop_idx: axes_i,
                    kind:     "array_element",
                    alias:    seg.to_s
                  }
                  kinds << :array_element
                  axes_i += 1
                else
                  loops << {
                    axes:     seg.to_sym,
                    path:     path_segs[0..idx].map(&:to_sym),
                    loop_idx: axes_i,
                    kind:     "array_field",
                    key:      seg.to_s
                  }
                  kinds << :array_field
                  axes_i += 1
                end
              elsif child_container == :scalar
                # scalar under array: either alias-to-scalar (arrays-of-scalars) or a field on the element
                if enter_via == :array || node.consume_alias
                  # arrays-of-scalars case → no field read; terminal.kind will be "element_leaf"
                  kinds << :element_leaf # direct element access, not field access
                else
                  kinds << :field_leaf
                end
              else
                kinds << :field_leaf
              end

            else
              raise "Invalid parent container #{parent_container.inspect} at #{path_segs.join('.')}"
            end

            parent   = node
            last_node = node
            cur      = node.children || {}
          end

          [loops, kinds, last_node]
        end

        # alias step if child is array and declared to be entered via array (or forced)
        def alias_step?(node)
          node.container == :array && (node.enter_via == :array || node.consume_alias)
        end

        # ---- metadata helpers ----
        def meta_node_for(path_segs)
          cur = @meta
          last = nil
          path_segs.each do |seg|
            last = cur[seg.to_sym] or return nil
            cur  = last.children || {}
          end
          last
        end

        def fetch_node!(cur, seg, full_path)
          cur[seg.to_sym] or raise ArgumentError,
            "Missing metadata for '#{seg}' in #{full_path.join('.')}. Available: #{cur.keys.inspect}"
        end

        def extract_dtype(root_meta, path_sym)
          node = path_sym.reduce(nil) do |acc, seg|
            acc ? (acc.children && acc.children[seg]) : root_meta[seg]
          end
          raise "No type for path #{path_sym.inspect}" unless node && node.respond_to?(:type)
          node.type
        end

        def raise_contract!(field, seg, full_path)
          raise ArgumentError, "Metadata contract violation: missing #{field} for '#{seg}' in '#{full_path.join('.')}'"
        end
      end
    end
  end
end