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
          @table    = {}
        end

        def plan
          @meta.each_key { |root| walk([root.to_s]) }
          # Instead of returning @table, we return its values
          @table.values.sort_by { |plan| plan[:path_fqn] }
        end

        private

        # def walk(path_segs)
        #   # The emit_entry method now directly creates the final InputPlan object.
        #   path_sym = path_segs.map(&:to_sym)
        #   @table[path_sym] = create_input_plan(path_segs)

        #   node = meta_node_for(path_segs)
        #   return unless node && node.children
        #   node.children.each_key { |k| walk(path_segs + [k.to_s]) }
        # end

        def walk(path_segs)
          path_sym = path_segs.map(&:to_sym)
          @table[path_sym] = create_input_plan(path_segs)

          node = meta_node_for(path_segs)
          return unless node && node.children

          node.children.each_key { |k| walk(path_segs + [k.to_s]) }
        end

        # This is the core method that builds the final, clean InputPlan object.
        def create_input_plan(path_segs)
          path_sym = path_segs.map(&:to_sym)
          node = meta_node_for(path_segs)
          dtype = node.type

          # A path's logical axes are determined by the loops needed to reach its PARENT.
          parent_path_sym = path_sym[0...-1]
          parent_plan = @table.fetch(parent_path_sym, nil)
          axes = parent_plan ? parent_plan.navigation_steps.filter_map { |step| step[:axis].to_sym if step[:kind] == "array_loop" } : []

          navigation_steps = compute_navigation_steps(path_segs)

          # If the path is an array, describe the axis of its elements.
          Core::Analyzer::Plans::InputPlan.new(
            source_path: path_sym,
            axes: axes,
            dtype: dtype,
            key_policy: @defaults[:key_policy],
            missing_policy: @defaults[:on_missing],
            navigation_steps: navigation_steps,
            path_fqn: path_segs.join(".")
          )
        end

        # This method now produces a single, unified list of navigation steps.
        def compute_navigation_steps(path_segs)
          steps = []
          loop_idx_counter = 0

          cur = @meta
          parent = nil

          path_segs.each_with_index do |seg, idx|
            node = fetch_node!(cur, seg, path_segs)
            parent_container = parent&.container || :object
            child_container  = node.container or raise_contract!(":container", seg, path_segs)
            enter_via        = (idx.zero? ? :hash : (node.enter_via or raise_contract!(":enter_via", seg, path_segs)))

            case parent_container
            when :object, :hash
              if child_container == :array
                steps << {
                  kind: "array_loop",
                  axis: seg.to_s,
                  path_fqn: path_segs[0..idx].join("."),
                  loop_idx: loop_idx_counter,
                  key: seg.to_s
                }
                loop_idx_counter += 1
              else
                steps << { kind: "property_access", key: seg.to_s }
              end

            when :array
              # We are inside an array element; the next step is either a
              # nested loop or a property access on the element.
              if child_container == :array
                steps << {
                  kind: "array_loop",
                  axis: seg.to_s,
                  path: path_segs[0..idx],
                  loop_idx: loop_idx_counter,
                  key: (alias_step?(node) ? nil : seg.to_s) # array_element has no key
                }
                loop_idx_counter += 1
              elsif child_container == :scalar
                steps << if enter_via == :array || node.consume_alias
                           # Array of scalars: the value is the element itself.
                           { kind: "element_access" }
                         else
                           # Array of objects: access a property on the element.
                           { kind: "property_access", key: seg.to_s }
                         end
              else
                steps << { kind: "property_access", key: seg.to_s }
              end
            else
              raise "Invalid parent container #{parent_container.inspect} at #{path_segs.join('.')}"
            end

            parent = node
            cur = node.children || {}
          end

          steps
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

        def extract_dtype(_root_meta, path_sym)
          node = meta_node_for(path_sym)
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
