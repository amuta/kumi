# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        class SNASTPass < PassBase
          reads :nast_module, :metadata_table, :declaration_table, :input_table, :index_table, :registry
          writes :snast_module
          def run(errors)
            @nast_module       = get_state(:nast_module,       required: true)
            @metadata_table    = get_state(:metadata_table,    required: true)
            @declaration_table = get_state(:declaration_table, required: true)
            @input_table       = get_state(:input_table,       required: true)
            @index_table       = get_state(:index_table,       required: true)
            @registry          = get_state(:registry,          required: true)
            @errors = errors

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
            meta = meta_for(n)
            out = n.class.new(id: n.id, value: n.value, loc: n.loc)
            stamp!(out, [], meta[:type])
          end

          def visit_input_ref(n)
            ent = lookup_input(n.path_fqn)
            out = n.class.new(id: n.id, path: n.path, loc: n.loc)
            stamp!(out, ent[:axes], ent[:dtype])
          end

          def visit_index_ref(n)
            m = meta_for(n)
            out = n.class.new(id: n.id, name: n.name, input_fqn: n.input_fqn, loc: n.loc)
            stamp!(out, m[:scope], m[:type])
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

          def visit_hash(n)
            pairs = n.pairs.map { _1.accept(self) }
            m    = meta_for(n)
            out  = n.class.new(id: n.id, pairs:, loc: n.loc)
            stamp!(out, m[:scope], m[:type])
          end

          def visit_pair(n)
            value = n.value.accept(self)
            m = meta_for(n)
            out = n.class.new(id: n.id, key: n.key, value:)
            stamp!(out, m[:scope], m[:type])
          end

          def visit_call(n)
            if @registry.select?(n.fn)
              c = n.args[0].accept(self)
              t = n.args[1].accept(self)
              f = n.args[2].accept(self)
              target_axes = lub_by_prefix([axes_of(t), axes_of(f)])
              target_axes = axes_of(c) if target_axes.empty?
              unless prefix?(axes_of(c), target_axes)
                halt_pass!(@errors,
                           "select mask axes #{axes_of(c).inspect} must prefix #{target_axes.inspect}",
                           location: n.loc)
              end

              out = NAST::Select.new(id: n.id, cond: c, on_true: t, on_false: f, loc: n.loc, meta: n.meta.dup)
              return stamp!(out, target_axes, dtype_of(t))
            end

            if @registry.reduce?(n.fn)
              # Reduce arity is fixed upstream; >1 arg here means the IR is malformed.
              raise Kumi::Core::Errors::CompilerBug, "reduce #{n.fn} has #{n.args.size} args, expected 1" if n.args.size != 1

              arg_node = n.args.first
              visited_arg = arg_node.accept(self)
              arg_meta = visited_arg[:meta]
              arg_type = arg_meta[:stamp][:dtype]

              if Kumi::Core::Types.collection?(arg_type)
                # --- Path for FOLD (Scalar or Vectorized) ---w
                # The argument is semantically a tuple. Create a Fold node.

                # We still need to visit the child node to build the SNAST tree

                fold_node = NAST::Fold.new(
                  id: n.id,
                  fn: @registry.resolve_id(n.fn),
                  arg: visited_arg, # The arg is the tuple/reference to the tuple
                  loc: n.loc,
                  meta: n.meta.dup
                )

                # The output type is the reduced scalar type (e.g., :integer for max).
                # The axes are PRESERVED because a fold is an element-wise operation
                # on the container of tuples.
                result_meta = meta_for(n)
                return stamp!(fold_node, result_meta[:result_scope], result_meta[:result_type])
              else
                # --- Path for REDUCE (Vectorized Arrays) ---
                in_axes = axes_of(visited_arg)

                halt_pass!(@errors, "reduce function called on a non-collection scalar: #{arg_type}", location: n.loc) if in_axes.empty?

                result_meta = meta_for(n)
                out_axes = Array(result_meta[:result_scope])

                unless prefix?(out_axes, in_axes)
                  halt_pass!(@errors,
                             "reduce: out axes #{out_axes.inspect} must prefix arg axes #{in_axes.inspect}",
                             location: n.loc)
                end

                over_axes = in_axes.drop(out_axes.length)
                reduce_node = NAST::Reduce.new(
                  id: n.id,
                  fn: @registry.resolve_id(n.fn),
                  over: over_axes,
                  arg: visited_arg,
                  loc: n.loc,
                  meta: n.meta.dup
                )
                return stamp!(reduce_node, out_axes, result_meta[:result_type])
              end
            end

            # regular elementwise
            args = n.args.map { _1.accept(self) }
            m    = meta_for(n)
            # Use the function ID from metadata (already resolved with type awareness in NASTDimensionalAnalyzerPass)
            fn_id = m[:function] || @registry.resolve_id(n.fn)
            out = n.class.new(id: n.id, fn: fn_id.to_sym, args:, opts: n.opts, loc: n.loc)
            stamp!(out, m[:result_scope], m[:result_type])
          end

          def visit_import_call(n)
            args = n.args.map { _1.accept(self) }
            m = meta_for(n)
            out = n.class.new(
              id: n.id,
              fn_name: n.fn_name,
              args: args,
              input_mapping_keys: n.input_mapping_keys,
              source_module: n.source_module,
              loc: n.loc,
              meta: n.meta.dup
            )
            stamp!(out, m[:result_scope], m[:result_type])
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
              raise Kumi::Core::Errors::CompilerBug, "axis prefix mismatch: #{ax.inspect} vs #{cand.inspect}" unless prefix?(ax, cand)
            end
            cand
          end

          def prefix?(pre, full)
            pre.each_with_index.all? { |tok, i| full[i] == tok }
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
