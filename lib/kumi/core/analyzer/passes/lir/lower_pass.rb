module Kumi
  module Core
    module Analyzer
      module Passes
        module LIR
          class LowerPass < PassBase
            include StencilEmitter

            NAST  = Kumi::Core::NAST
            Ids   = Kumi::Core::LIR::Ids
            Build = Kumi::Core::LIR::Build
            Emit  = Kumi::Core::LIR::Emit

            def run(_errors)
              @snast    = get_state(:snast_module, required: true)
              @registry = get_state(:registry, required: true)
              @ids      = Ids.new
              @anchors  = get_state(:anchor_by_decl, required: true)
              @pre      = get_state(:precomputed_plan_by_fqn, required: true)
              plans     = get_state(:input_table, required: true)
              @plans_by_fqn = plans.each_with_object({}) { |p, h| h[p.path_fqn.to_s] = p }

              ops_by_decl = {}
              @snast.decls.each do |name, decl|
                @ops = []
                @env = Env.new
                @current_decl = decl
                lower_declaration(decl)
                ops_by_decl[name] = { operations: @ops }
              end

              ops_by_decl.freeze
              state.with(:lir_module, ops_by_decl)
                   .with(:lir_00_unoptimized, ops_by_decl)
                   .with(:id_generator, @ids)
            end

            private

            Env = Struct.new(:frames, :memo, keyword_init: true) do
              def initialize(**) = super(frames: [], memo: Hash.new { |h, k| h[k] = {} })
              def axes      = frames.map { _1[:axis] }
              def loop_ids  = frames.map { _1[:id] }
              def element_reg_for(axis)    = frames.reverse.find { _1[:axis] == axis }&.dig(:as_element)
              def index_reg_for(axis)      = frames.reverse.find { _1[:axis] == axis }&.dig(:as_index)
              def collection_reg_for(axis) = frames.reverse.find { _1[:axis] == axis }&.dig(:collection)
              def push(frame) = frames << frame
              def pop         = frames.pop
              def depth       = frames.length
              def memo_get(cat, key) = memo[cat][key]
              def memo_set(cat, key, val) = memo[cat][key] = val
              def invalidate_after_depth!(_d); end
            end

            # ---------- declarations ----------

            def lower_declaration(decl)
              wanted = axes_of(decl)
              wanted = axes_of(decl.body) if wanted.empty?

              if wanted.empty?
                close_loops_to_depth(0)
              else
                ensure_context_for!(wanted, anchor_fqn: anchor_fqn_from_node!(decl.body, need_prefix: wanted))
              end

              @emit = Emit.new(registry: @registry, ids: @ids, ops: @ops)
              res = lower_expr(decl.body)
              @ops << Build.yield(result_register: res)
            ensure
              close_loops_to_depth(0)
            end

            # ---------- expressions ----------

            def lower_expr(node)
              case node
              when NAST::Const       then emit_const(node)
              when NAST::InputRef    then emit_input_ref(node)
              when NAST::Ref         then emit_ref(node)
              when NAST::Tuple       then emit_tuple(node)
              when NAST::Select      then emit_select(node)
              when NAST::Fold        then emit_fold(node)
              when NAST::Reduce      then emit_reduce(node)
              when NAST::Call        then call_emit_selection(node)
              when NAST::Hash        then emit_hash(node)
              when NAST::IndexRef    then emit_index_ref(node)
              when NAST::ImportCall  then emit_import_call(node)
              else raise "unknown node #{node.class}"
              end
            end

            def call_emit_selection(n)
              return emit_roll(n)  if n.fn == :roll
              return emit_shift(n) if n.fn == :shift

              emit_call(n)
            end

            def emit_const(n)
              ins = Build.constant(value: n.value, dtype: dtype_of(n), ids: @ids)
              @ops << ins
              ins.result_register
            end

            def emit_ref(n)
              ins = Build.load_declaration(name: n.name, dtype: dtype_of(n), axes: axes_of(n), ids: @ids)
              @ops << ins
              ins.result_register
            end

            def emit_tuple(n)
              regs = n.args.map { lower_expr(_1) }
              ins  = Build.make_tuple(elements: regs, out_dtype: dtype_of(n), ids: @ids)
              @ops << ins
              ins.result_register
            end

            def emit_hash(n)
              keys = []
              vals = []
              n.pairs.each do |p|
                keys << p.key
                vals << lower_expr(p.value)
              end
              ins = Build.make_object(keys:, values: vals, ids: @ids)
              @ops << ins
              ins.result_register
            end

            def emit_call(n)
              regs = n.args.map { lower_expr(_1) }
              ins  = Build.kernel_call(
                function: @registry.resolve_function(n.fn),
                args: regs,
                out_dtype: dtype_of(n),
                ids: @ids
              )
              @ops << ins
              ins.result_register
            end

            def emit_import_call(n)
              regs = n.args.map { lower_expr(_1) }
              ins = Build.import_schema_call(
                fn_name: n.fn_name,
                source_module: n.source_module,
                args: regs,
                input_mapping_keys: n.input_mapping_keys,
                out_dtype: dtype_of(n),
                ids: @ids
              )
              @ops << ins
              ins.result_register
            end

            def emit_select(n)
              ax = axes_of(n)
              ensure_context_for!(ax, anchor_fqn: anchor_fqn_from_node!(n, need_prefix: ax)) unless ax.empty?
              c = lower_expr(n.cond)
              t = lower_expr(n.on_true)
              f = lower_expr(n.on_false)
              ins = Build.select(cond: c, on_true: t, on_false: f, out_dtype: dtype_of(n), ids: @ids)
              @ops << ins
              ins.result_register
            end

            def emit_fold(n)
              arg = lower_expr(n.arg)
              ins = Build.fold(arg:, function: @registry.resolve_function(n.fn), out_dtype: dtype_of(n), ids: @ids)
              @ops << ins
              ins.result_register
            end

            def emit_reduce(n)
              out_axes = axes_of(n)
              in_axes  = axes_of(n.arg)
              function = @registry.resolve_function(n.fn)
              raise "reduce: scalar input" if in_axes.empty?
              raise "reduce: axes(arg)=#{in_axes} must equal out+over" unless in_axes == out_axes + Array(n.over)

              ensure_context_for!(out_axes, anchor_fqn: anchor_fqn_from_node!(n.arg, need_prefix: out_axes))

              dtype    = dtype_of(n)
              acc_name = @ids.generate_temp(prefix: :acc_)
              @ops << Build.declare_accumulator(name: acc_name, dtype: dtype, ids: @ids)

              open_suffix_loops!(over_axes: Array(n.over), anchor_fqn: anchor_fqn_from_node!(n.arg, need_prefix: in_axes))

              val = lower_expr(n.arg)
              @ops << Build.accumulate(accumulator: acc_name, dtype: dtype, function: function, value_register: val)

              close_loops_to_depth(out_axes.length)
              ins = Build.load_accumulator(accumulator: acc_name, dtype: dtype, ids: @ids)
              @ops << ins
              ins.result_register
            end

            # ---------- InputRef ----------

            def emit_input_ref(n)
              axes = axes_of(n)
              keys = ir_key_chain(n)

              if axes.empty?
                # root access by explicit keys
                raise "root access needs key_chain" if keys.empty?

                head_dt = (keys.length == 1 ? dtype_of(n) : :any)
                cur = Build.load_input(key: keys.first.to_sym, dtype: head_dt, ids: @ids).tap { @ops << _1 }.result_register
                keys.drop(1).each_with_index do |k, i|
                  last = (i == keys.length - 2)
                  dt   = last ? dtype_of(n) : :any
                  cur  = Build.load_field(object_register: cur, key: k.to_sym, dtype: dt, ids: @ids).tap { @ops << _1 }.result_register
                end
                return cur
              end

              # inside loops: start from current element for innermost axis
              cur = @env.element_reg_for(axes.last) or raise "no open element for axis #{axes.last.inspect}"
              keys.each_with_index do |k, i|
                last = (i == keys.length - 1)
                dt   = last ? dtype_of(n) : :any
                cur  = Build.load_field(object_register: cur, key: k.to_sym, dtype: dt, ids: @ids).tap { @ops << _1 }.result_register
              end
              cur
            end

            def emit_index_ref(n)
              ax = axes_of(n)
              raise "index ref without axes" if ax.empty?

              debug "emit_index_ref: name=#{n.name}, axes=#{ax.inspect}, input_fqn=#{n.input_fqn}, env.axes=#{@env.axes.inspect}"

              # IndexRef nodes reference an index that should already be in scope.
              # The index refers to the LAST axis in the IndexRef's own stamp.
              # We do NOT open loops for broadcast axes - those loops should already be open
              # from other parts of the expression.
              target_axis = ax.last

              # The index variable is defined by the array that introduced this axis.
              idx = @env.index_reg_for(target_axis) or raise "no index register for axis #{target_axis.inspect}"

              debug "emit_index_ref: returning index register #{idx.inspect} for axis #{target_axis}"

              # Index is an integer scalar elementwise over the current axes ⇒ just return the register.
              idx
            end

            # ---------- context management ----------

            def ensure_context_for!(target_axes, anchor_fqn:)
              l = lcp(@env.axes, target_axes).length
              close_loops_to_depth(l)
              missing = target_axes[l..] || []
              return if missing.empty?

              open_suffix_loops!(over_axes: missing, anchor_fqn: anchor_fqn)
            end

            def open_suffix_loops!(over_axes:, anchor_fqn:)
              return if over_axes.empty?

              target_axes = @env.axes + over_axes
              pre = @pre.fetch(anchor_fqn) { raise "no precomputed plan for #{anchor_fqn}" }

              axis_to_loop = pre[:axis_to_loop] || {}
              idxs = target_axes.map { |ax| axis_to_loop.fetch(ax) { raise "plan #{anchor_fqn} lacks axis #{ax.inspect}" } }

              base = @env.axes.length
              (base...target_axes.length).each do |i|
                axis  = target_axes[i]
                li    = idxs[i]

                coll =
                  if i == 0 && base == 0
                    head_collection(pre, li)
                  else
                    prev_axis = target_axes[i - 1]
                    prev_el   = @env.element_reg_for(prev_axis) or raise "no element for #{prev_axis}"
                    prev_li   = idxs[i - 1]
                    between_loops(pre, prev_li, li, prev_el)
                  end

                el  = @ids.generate_temp(prefix: :"#{axis}_el_")
                ix  = @ids.generate_temp(prefix: :"#{axis}_i_")
                lid = @ids.generate_loop_id
                @ops << Build.loop_start(collection_register: coll, axis: axis, as_element: el, as_index: ix, id: lid)
                @env.push(axis: axis, as_element: el, as_index: ix, id: lid, collection: coll)
              end
            end

            def close_loops_to_depth(depth)
              while @env.depth > depth
                @env.pop
                @ops << Build.loop_end
              end
              @env.invalidate_after_depth!(depth)
            end

            # ---------- small utils ----------

            def axes_of(n)  = Array(n.meta[:stamp]&.dig(:axes))
            def dtype_of(n) = n.meta[:stamp]&.dig(:dtype)

            def lcp(a, b)
              i = 0
              i += 1 while i < a.size && i < b.size && a[i] == b[i]
              a[0...i]
            end

            def ir_fqn(n)         = n.instance_variable_get(:@fqn) || n.path.join(".")
            def ir_key_chain(n)   = Array(n.instance_variable_get(:@key_chain))
            def plan_for_fqn(fqn) = @plans_by_fqn.fetch(fqn) { raise "no InputPlan for #{fqn}" }

            def anchor_fqn_from_node!(node, need_prefix:)
              ir = find_anchor_inputref(node, need_prefix: need_prefix)
              return ir if ir.is_a? String

              ir_fqn(ir)
            end

            def find_anchor_inputref(node, need_prefix:)
              found = nil
              walk = lambda do |x|
                case x
                when NAST::InputRef
                  ax = axes_of(x)
                  found ||= x if need_prefix.each_with_index.all? { |tok, i| ax[i] == tok }
                when NAST::Ref
                  decl = @snast.decls.fetch(x.name) { raise "unknown declaration #{x.name}" }
                  walk.call(decl.body)
                when NAST::Select
                  walk.call(x.cond)
                  walk.call(x.on_true)
                  walk.call(x.on_false)
                when NAST::Reduce, NAST::Fold
                  walk.call(x.arg)
                when NAST::Call, NAST::Tuple
                  x.args.each { walk.call(_1) }
                when NAST::Hash
                  x.pairs.each { walk.call(_1) }
                when NAST::Pair
                  walk.call(x.value)
                when NAST::IndexRef
                  ax = axes_of(x)
                  found ||= x.input_fqn if need_prefix.each_with_index.all? { |tok, i| ax[i] == tok }
                end
              end
              walk.call(node)
              found or raise "no anchor InputRef covering axes #{need_prefix.inspect}"
            end

            # ---------- path caches (no dtype checks) ----------

            # --- replace head_collection entirely ---
            def head_collection(pre, li)
              key = [pre.object_id, li]
              @env.memo_get(:head, key) || begin
                reg = nil
                path = Array(pre[:head_path_by_loop][li])

                if path.empty?
                  # Defensive fallback: loop step carries the root key in pre[:steps][li]
                  step = pre[:steps][li] or raise "no step at loop index #{li}"
                  root_key = (step[:key] || step[:axis]).to_sym
                  reg = Build.load_input(key: root_key, dtype: :array, ids: @ids).tap { @ops << _1 }.result_register
                  @env.memo_set(:head, key, reg)
                  return reg
                end

                path.each do |kind, ksym|
                  case kind
                  when :input
                    reg = Build.load_input(key: ksym, dtype: :array, ids: @ids).tap { @ops << _1 }.result_register
                  when :field
                    raise "head path field before input" if reg.nil?

                    reg = Build.load_field(object_register: reg, key: ksym, dtype: :any, ids: @ids).tap do
                      @ops << _1
                    end.result_register
                  else
                    raise "unknown head hop #{kind.inspect}"
                  end
                end

                @env.memo_set(:head, key, reg)
              end
            end

            def between_loops(pre, li_from, li_to, start_el_reg)
              keys = pre[:between_loops].fetch([li_from, li_to], [])
              return start_el_reg if keys.empty?

              k = [start_el_reg.object_id, pre.object_id, li_from, li_to]
              @env.memo_get(:between, k) || begin
                cur = start_el_reg
                keys.each do |sym|
                  cur = Build.load_field(object_register: cur, key: sym, dtype: :any, ids: @ids).tap { @ops << _1 }.result_register
                end
                @env.memo_set(:between, k, cur)
              end
            end

            def length_of(reg)
              k = reg.object_id
              @env.memo_get(:len, k) || @env.memo_set(:len, k, @emit.length(reg))
            end

            def clamped_index(idx_reg, coll_reg)
              k = [idx_reg.object_id, coll_reg.object_id]
              @env.memo_get(:clamp_idx, k) || begin
                hi = @emit.sub_i(length_of(coll_reg), @emit.iconst(1))
                @env.memo_set(:clamp_idx, k, @emit.clamp(idx_reg, @emit.iconst(0), hi, out: :integer))
              end
            end
          end
        end
      end
    end
  end
end
