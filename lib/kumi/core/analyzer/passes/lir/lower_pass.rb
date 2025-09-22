# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        module LIR
          # SNAST → LIR (baseline, carrier-free).
          #
          # Deterministic lowerer that:
          # - Aligns loop context Γ to node.axes via LCP(Γ, axes) + open(missing).
          # - Opens loops using the anchor InputRef's InputPlan (navigation_steps).
          # - Emits Reduce as declare→open(over)→accumulate→close→load.
          # - Uses InputRef annotations from AttachTerminalInfoPass:
          #     @fqn, @key_chain (Array<Symbol>), @element_terminal (Boolean).
          # - No fusion/CSE/scheduling; output is optimization-friendly.
          #
          # Inputs (state):
          #   :snast_module   => Kumi::Core::NAST::Module (stamped nodes)
          #   :registry       => function/kernel registry
          #   :ir_input_plans => [Plans::InputPlan] with navigation_steps
          #
          # Output (state):
          #   :lir_module => { decl_name => { operations: [Instruction...] } }
          class LowerPass < PassBase
            NAST = Kumi::Core::NAST
            Ids = Kumi::Core::LIR::Ids
            Literal = Kumi::Core::LIR::Literal
            Build = Kumi::Core::LIR::Build

            def run(_errors)
              @snast    = get_state(:snast_module, required: true)
              @registry = get_state(:registry, required: true)
              @ids      = Ids.new
              @target_platform = get_state(:target_platform, required: false) || :ruby

              # Deterministic loop opening comes from plans (no carriers).
              plans = get_state(:ir_input_plans, required: true)
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

            Env = Struct.new(:frames, keyword_init: true) do
              def initialize(**) = super(frames: [])
              def axes      = frames.map { _1[:axis] }
              def loop_ids  = frames.map { _1[:id] }
              def element_reg_for(axis) = frames.reverse.find { _1[:axis] == axis }&.dig(:as_element)
              def index_reg_for(axis)   = frames.reverse.find { _1[:axis] == axis }&.dig(:as_index)
              def push(frame) = frames << frame
              def pop         = frames.pop
              def depth       = frames.length
            end

            # ---------- declarations ----------

            def lower_declaration(decl)
              wanted = axes_of(decl)
              if wanted.empty?
                close_loops_to_depth(0)
              else
                anchor = find_anchor_inputref(decl.body, need_prefix: wanted)
                ensure_context_for!(wanted, anchor:)
              end
              res = lower_expr(decl.body)
              @ops << Build.yield(result_register: res)
            ensure
              close_loops_to_depth(0)
            end

            # ---------- expressions ----------

            def lower_expr(node)
              case node
              when NAST::Const    then emit_const(node)
              when NAST::InputRef then emit_input_ref(node)
              when NAST::Ref      then emit_ref(node)
              when NAST::Tuple    then emit_tuple(node)
              when NAST::Select   then emit_select(node)
              when NAST::Fold     then emit_fold(node)
              when NAST::Reduce   then emit_reduce(node)
              when NAST::Call     then emit_call(node)
              when NAST::Hash     then emit_hash(node)
              else raise "unknown node #{node.class}"
              end
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
              values = []
              keys = []
              n.pairs.each do |pair|
                keys << pair.key
                values << lower_expr(pair.value)
              end

              ins = Build.make_object(keys:, values:, ids: @ids)
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

            def emit_select(n)
              ensure_context_for!(axes_of(n), anchor: n)
              c = lower_expr(n.cond)
              t = lower_expr(n.on_true)
              f = lower_expr(n.on_false)
              ins = Build.select(cond: c, on_true: t, on_false: f, out_dtype: dtype_of(n), ids: @ids)
              @ops << ins
              ins.result_register
            end

            def emit_fold(n)
              arg = lower_expr(n.arg)

              ins = Build.fold(
                arg:,
                function: @registry.resolve_function(n.fn),
                out_dtype: dtype_of(n),
                ids: @ids
              )
              @ops << ins
              ins.result_register
            end

            def emit_reduce(n)
              out_axes = axes_of(n)
              in_axes  = axes_of(n.arg)
              function = @registry.resolve_function(n.fn)
              raise "reduce: scalar input" if in_axes.empty?
              raise "reduce: axes(arg)=#{in_axes} must equal out+over" unless in_axes == out_axes + Array(n.over)

              ensure_context_for!(out_axes, anchor: n.arg)

              dtype    = dtype_of(n)
              acc_name = @ids.generate_temp(prefix: :acc_)
              @ops << Build.declare_accumulator(name: acc_name, dtype: dtype, ids: @ids)

              open_suffix_loops!(over_axes: Array(n.over), anchor: n.arg)
              val = lower_expr(n.arg)
              @ops << Build.accumulate(accumulator: acc_name, dtype: dtype, function: function,
                                       value_register: val)

              close_loops_to_depth(out_axes.length)
              ins = Build.load_accumulator(accumulator: acc_name, dtype: dtype, ids: @ids)
              @ops << ins
              ins.result_register
            end

            # ---------- InputRef lowering ----------

            def emit_input_ref(n)
              axes = axes_of(n)
              keys = ir_key_chain(n)

              if axes.empty?
                # Root-scoped access (no open loops).
                if keys.empty?
                  # Whole-root access; load the plan head key with the node's dtype.
                  plan = plan_for_fqn(ir_fqn(n))
                  steps    = Array(plan.navigation_steps).map { |h| h.transform_keys(&:to_sym) }
                  loop_ix  = steps.each_index.find { |i| steps[i][:kind].to_s == "array_loop" }

                  first, *mid, last = steps[..loop_ix].map { _1[:key].to_sym }
                  only_first = mid.empty? && !last
                  first_dtype = only_first ? :array : :hash

                  reg = Build.load_input(key: first, dtype: first_dtype, ids: @ids).tap { @ops << _1 }.result_register

                  mid.each do |key|
                    reg = Build.load_field(object_register: reg, key: key,
                                           dtype: :hash, ids: @ids).tap { @ops << _1 }.result_register
                  end

                  reg ||= Build.load_field(object_register: reg, key: last,
                                           dtype: :array, ids: @ids).tap { @ops << _1 }.result_register

                  return reg
                end

                head_dtype = (keys.length == 1 ? dtype_of(n) : :hash)
                cur = Build.load_input(key: keys.first.to_sym, dtype: head_dtype, ids: @ids).tap { @ops << _1 }.result_register

                keys.drop(1).each_with_index do |k, i|
                  last = (i == keys.length - 2)
                  field_dtype = last ? dtype_of(n) : :hash
                  cur = Build.load_field(object_register: cur, key: k.to_sym, dtype: field_dtype, ids: @ids).tap do
                    @ops << _1
                  end.result_register
                end
                return cur
              end

              # Inside loops: start from the current element of the deepest axis.
              cur = @env.element_reg_for(axes.last) or raise "no open element for axis #{axes.last.inspect}"
              keys.each_with_index do |k, i|
                last = (i == keys.length - 1)
                field_dtype = last ? dtype_of(n) : :hash
                cur = Build.load_field(object_register: cur, key: k.to_sym, dtype: field_dtype, ids: @ids).tap do
                  @ops << _1
                end.result_register
              end
              cur
            end

            # ---------- context management ----------

            def ensure_context_for!(target_axes, anchor:)
              l = lcp(@env.axes, target_axes).length
              close_loops_to_depth(l)
              missing = target_axes[l..] || []
              return if missing.empty?
              raise "need anchor InputRef to open loops for #{missing.inspect}" unless anchor

              open_suffix_loops!(over_axes: missing, anchor:)
            end

            # Open missing suffix loops using the anchor's InputPlan.navigation_steps.
            def open_suffix_loops!(over_axes:, anchor:)
              return if over_axes.empty?

              target_axes = @env.axes + over_axes
              anchor_ir   = find_anchor_inputref(anchor, need_prefix: target_axes)
              plan        = plan_for_fqn(ir_fqn(anchor_ir))

              steps    = Array(plan.navigation_steps).map { |h| h.transform_keys(&:to_sym) }
              loop_ix  = steps.each_index.select { |i| steps[i][:kind].to_s == "array_loop" }
              loop_axes = loop_ix.map { |i| steps[i][:axis].to_sym }

              idxs = target_axes.map do |ax|
                j = loop_axes.index(ax) or raise "anchor plan #{plan.path_fqn} lacks axis #{ax.inspect}"
                loop_ix[j]
              end

              base = @env.axes.length
              (base...target_axes.length).each do |i|
                cur_axis   = target_axes[i]
                cur_loopi  = idxs[i]
                prev_loopi = (i == 0 ? -1 : idxs[i - 1])

                coll =
                  if i == 0 && base == 0
                    # TODO: This SHOULD NOT BE HERE.
                    # But this is getting too complex...
                    # it seems simple but the access plans are very hard to get right
                    first, *mid, last = steps[..cur_loopi].map { _1[:key].to_sym }
                    only_first = mid.empty? && !last
                    first_dtype = only_first ? :array : :hash

                    reg = Build.load_input(key: first, dtype: first_dtype, ids: @ids).tap { @ops << _1 }.result_register

                    mid.each do |key|
                      reg = Build.load_field(object_register: reg, key: key,
                                             dtype: :hash, ids: @ids).tap { @ops << _1 }.result_register
                    end

                    if last
                      reg = Build.load_field(object_register: reg, key: last,
                                             dtype: :array, ids: @ids).tap { @ops << _1 }.result_register
                    end

                    reg
                  else
                    # Walk any property_access between previous loop and current loop.
                    prev_axis = target_axes[i - 1]
                    reg = @env.element_reg_for(prev_axis) or raise "no element for #{prev_axis}"

                    ((prev_loopi + 1)...cur_loopi).each do |k|
                      st = steps[k]
                      next unless st[:kind].to_s == "property_access"

                      reg = Build.load_field(object_register: reg, key: st[:key].to_sym,
                                             dtype: :hash, ids: @ids).tap { @ops << _1 }.result_register
                    end

                    key = steps[cur_loopi][:key]
                    if key
                      Build.load_field(object_register: reg, key: key.to_sym, dtype: :array, ids: @ids).tap { @ops << _1 }.result_register
                    else
                      # The element itself is the collection for the next loop.
                      reg
                    end
                  end

                el  = @ids.generate_temp(prefix: :"#{cur_axis}_el_")
                ix  = @ids.generate_temp(prefix: :"#{cur_axis}_i_")
                lid = @ids.generate_loop_id
                @ops << Build.loop_start(collection_register: coll, axis: cur_axis, as_element: el, as_index: ix, id: lid)
                @env.push(axis: cur_axis, as_element: el, as_index: ix, id: lid)
              end
            end

            def close_loops_to_depth(depth)
              while @env.depth > depth
                @env.pop
                @ops << Build.loop_end
              end
            end

            # ---------- utils ----------

            def axes_of(n)  = Array(n.meta[:stamp]&.dig(:axes))
            def dtype_of(n) = n.meta[:stamp]&.dig(:dtype)

            def lcp(a, b)
              i = 0
              i += 1 while i < a.size && i < b.size && a[i] == b[i]
              a[0...i]
            end

            def prefix?(pre, full)
              pre.each_with_index.all? { |tok, i| full[i] == tok }
            end

            # ---- InputRef annotations & plans ----

            def ir_fqn(n)         = n.instance_variable_get(:@fqn) || n.path.join(".")
            def ir_key_chain(n)   = Array(n.instance_variable_get(:@key_chain))
            def plan_for_fqn(fqn) = @plans_by_fqn.fetch(fqn) { raise "no InputPlan for #{fqn}" }

            def find_anchor_inputref(node, need_prefix:)
              found = nil

              walk = lambda do |x|
                case x
                when NAST::InputRef
                  ax = axes_of(x)
                  found ||= x if prefix?(need_prefix, ax)
                when NAST::Ref
                  # Follow the reference into its declaration body
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
                end
              end

              walk.call(node)
              found or raise "no anchor InputRef covering axes #{need_prefix.inspect}"
            end
          end
        end
      end
    end
  end
end
