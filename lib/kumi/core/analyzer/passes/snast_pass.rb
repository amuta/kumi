# frozen_string_literal: true
#
module Kumi
  module Core
    module Analyzer
      module Passes
        # Semantic NAST Pass (SNAST)
        # - Rewrites intrinsic control and reductions into first-class nodes.
        # - Attaches semantic stamps to every node: meta[:stamp] = { axes:, dtype: }.
        # - Uses side tables for types/scopes; no meta[:plan].
        #
        # Reduction rule (default sugar):
        #   If not explicitly annotated, a reduction over arguments reduces the LAST axis:
        #     a = lub_by_prefix(arg_axes_list)
        #     over = [a.last]; out_axes = a[0...-1]
        #
        # Inputs (state):
        #   :nast_module          => Kumi::Core::NAST::Module (topologically ordered)
        #   :metadata_table       => Hash[node_key => { result_scope:, result_type:, arg_scopes?: ... }]
        #   :declaration_table    => Hash[name => { result_scope:, result_type: }]
        #   :input_table          => [{path_fqn:, axes:, dtype:}] or Hash[path_fqn] => { axes:, dtype: }
        #
        # Output (state):
        #   :snast_module         => Kumi::Core::NAST::Module (with NAST::Select / NAST::Reduce nodes)
        #
        # TODO: If downstream never keys by node ids, consider removing dependence on node.id.
        class SNASTPass < PassBase
          BUILTIN_SELECT = :__select__
          REDUCE_IDS = [:"agg.sum"].freeze # extend as you add reducers

          def run(errors)
            @nast_module       = get_state(:nast_module,       required: true)
            @metadata_table    = get_state(:metadata_table,    required: true)
            @declaration_table = get_state(:declaration_table, required: true)
            @input_table       = get_state(:input_table,       required: true)

            debug "Building SNAST from #{@nast_module.decls.size} declarations"
            snast_module = @nast_module.accept(self)
            state.with(:snast_module, snast_module.freeze)
          end

          # ---------- Visitor entry points ----------

          def visit_module(mod)
            # decls is expected to be a Hash[name => Declaration]
            mod.class.new(decls: mod.decls.transform_values { |d| d.accept(self) })
          end

          def visit_declaration(d)
            meta = @declaration_table.fetch(d.name)
            body = d.body.accept(self)
            out  = d.class.new(id: d.id, name: d.name, body:, loc: d.loc, meta: { kind: d.kind })
            stamp!(out, meta[:result_scope], meta[:result_type])
          end

          # ---------- Leaves ----------

          def visit_const(n)
            dt =
              case n.value
              when Integer     then :integer
              when Float       then :float
              when String      then :string
              when true, false then :boolean
              else raise "Unknown constant type: #{n.value.class}"
              end
            out = n.class.new(id: n.id, value: n.value, loc: n.loc)
            stamp!(out, [], dt)
          end

          def visit_input_ref(n)
            ent = lookup_input(n.path_fqn)
            out = n.class.new(id: n.id, path: n.path, loc: n.loc)
            stamp!(out, ent[:axes], ent[:dtype])
          end

          def visit_ref(n)
            m = meta_for(n)
            out = n.class.new(id: n.id, name: n.name, loc: n.loc)
            stamp!(out, m[:result_scope], m[:result_type])
          end

          def visit_tuple(n)
            args = n.args.map { _1.accept(self) }
            m    = meta_for(n)
            out  = n.class.new(id: n.id, args:, loc: n.loc)
            stamp!(out, m[:result_scope], m[:result_type])
          end

          # ---------- Calls and rewrites ----------

          def visit_call(n)
            return visit_select(rewrite_select(n))           if n.fn == BUILTIN_SELECT
            return visit_reduce(rewrite_reduce(n, meta_for(n))) if REDUCE_IDS.include?(n.fn)

            args = n.args.map { _1.accept(self) }
            m    = meta_for(n)
            out  = n.class.new(id: n.id, fn: n.fn, args:, loc: n.loc)
            stamp!(out, m[:result_scope], m[:result_type])
          end

          # Select

          def rewrite_select(call)
            c, t, f = call.args
            NAST::Select.new(id: call.id, cond: c, on_true: t, on_false: f, loc: call.loc, meta: call.meta.dup)
          end

          def visit_select(n)
            c = n.cond.accept(self)
            t = n.on_true.accept(self)
            f = n.on_false.accept(self)

            target_axes = lub_by_prefix([axes_of(t), axes_of(f)])
            target_axes = axes_of(c) if target_axes.empty? # both branches scalar
            raise Kumi::Core::Errors::SemanticError, "select mask axes #{axes_of(c).inspect} must prefix #{target_axes.inspect}" unless prefix?(axes_of(c), target_axes)

            out = n.class.new(id: n.id, cond: c, on_true: t, on_false: f, loc: n.loc)
            stamp!(out, target_axes, dtype_of(t))
          end

          # Reduce

          def rewrite_reduce(call, call_meta)
            # prefer table-provided arg scopes if present; else leave empty and compute after visiting child
            arg = call.args.first
            NAST::Reduce.new(
              id: call.id,
              op_id: call.fn,           # e.g., :"agg.sum"
              over: [],                  # filled on annotate-time if empty
              arg: arg,
              loc: call.loc,
              meta: call.meta.dup
            )
          end

          def visit_reduce(n)
            arg = n.arg.accept(self)

            # Out stamp prefers metadata table; otherwise use node.meta if present
            tmeta    = @metadata_table[node_key(n)]
            out_axes = (tmeta && tmeta[:result_scope]) || (n.meta[:stamp]&.dig(:axes) || [])
            out_dtype= (tmeta && tmeta[:result_type])  || dtype_of(arg) # TODO: replace with a promotion rule if needed

            in_axes  = axes_of(arg)
            over_axes =
              if n.over && !n.over.empty?
                n.over
              else
                # default sugar: reduce last axis
                reduce_last_axis([in_axes])[:over]
              end

            # Validate prefix law for reduce
            unless prefix?(out_axes, in_axes - over_axes)
              # out_axes must equal in_axes with over_axes removed at the tail for the default sugar
              # If you later support arbitrary axes order, change this check.
              expected = in_axes[0...(in_axes.length - over_axes.length)]
              raise Kumi::Core::Errors::SemanticError, "reduce out axes #{out_axes.inspect} must equal #{expected.inspect}"
            end

            out = n.class.new(id: n.id, op_id: n.op_id, over: over_axes, arg:, loc: n.loc)
            stamp!(out, out_axes, out_dtype)
          end

          # ---------- Helpers ----------

          def stamp!(node, axes, dtype)
            node.meta[:stamp] = { axes: Array(axes), dtype: dtype }.freeze
            node
          end

          def meta_for(node) = @metadata_table.fetch(node_key(node))

          def axes_of(n)  = Array(n.meta[:stamp]&.dig(:axes))
          def dtype_of(n) = n.meta[:stamp]&.dig(:dtype)

          # Least upper bound by prefix. All entries must be a prefix of the longest.
          def lub_by_prefix(list)
            return [] if list.empty?
            cand = list.max_by(&:length) || []
            list.each do |ax|
              raise Kumi::Core::Errors::SemanticError, "prefix mismatch: #{ax.inspect} vs #{cand.inspect}" unless prefix?(ax, cand)
            end
            cand
          end

          def prefix?(pre, full)
            pre.each_with_index.all? { |tok, i| full[i] == tok }
          end

          # Default reduce sugar: over last axis of the LUB of argument axes.
          # Returns { over:, out_axes: }.
          def reduce_last_axis(args_axes_list)
            a = lub_by_prefix(args_axes_list)
            raise Kumi::Core::Errors::SemanticError, "cannot reduce scalar" if a.empty?
            { over: [a.last], out_axes: a[0...-1] }
          end

          def lookup_input(fqn)
            if @input_table.respond_to?(:find)
              @input_table.find { |x| x[:path_fqn] == fqn } || raise("Input not found for #{fqn}")
            else
              @input_table.fetch(fqn) { raise("Input not found for #{fqn}") }
            end
          end

          def node_key(n) = "#{n.class}_#{n.id}"
        end
      end
    end
  end
end
