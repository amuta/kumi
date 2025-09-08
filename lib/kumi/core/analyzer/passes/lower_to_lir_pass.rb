# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        # SNAST → LIR (baseline). Emits loops, selects, and reducers as-is.
        #
        # Deterministic lowerer with a strict carrier policy:
        # - Each loop axis must have one canonical InputRef path observed in the module.
        #   Ambiguity raises. Absence raises.
        # - Loop context Γ (active axes) is aligned to a node by closing to LCP(Γ,node.axes)
        #   then opening the missing suffix.
        # - Reduce(op, over, arg): declare acc at Γ, open `over`, accumulate, close `over`,
        #   load acc at Γ.
        # - No fusion, CSE, or rescheduling. Output is a stable, optimization-friendly LIR.
        #
        # Assumptions:
        # - All NAST nodes are stamped: node.meta[:stamp] => { axes: [...], dtype: ... }.
        # - Axes semantics have been prevalidated; no cross-axis mismatches remain.
        #
        # Errors raised:
        # - Ambiguous carriers for an axes vector.
        # - Missing carrier for required axes.
        # - Reduce with scalar input or mismatched axes(out+over ≠ arg.axes).
        class LowerToLIRPass < PassBase
          NAST  = Kumi::Core::NAST
          LIR   = Kumi::Core::LIR
          Build = Kumi::Core::LIR::Build

          # Build LIR for the whole module.
          # - Builds a strict module-wide carrier map from InputRef nodes.
          # - Lowers each declaration in topo order.
          # @param errors [Array] not used here (structural errors raise)
          # @return [AnalysisState] state.with(:lir_ops_by_decl, …)
          def run(errors)
            @snast    = get_state(:snast_module, required: true)
            @registry = get_state(:registry,     required: true)
            @ids      = LIR::Ids.new
          
            # Strict, module-wide carrier map. Ambiguity => error.
            @carriers = build_carrier_map(@snast)
          
            ops_by_decl = {}
            @snast.decls.each do |name, decl|
              @ops = []
              @env = Env.new
              @current_decl = decl
              lower_declaration(decl)
              ops_by_decl[name] = { operations: @ops }
            end

            state.with(:lir_ops_by_decl, ops_by_decl.freeze)
          end

          private

          Env = Struct.new(:frames, keyword_init: true) do
            def initialize(**) = super(frames: [])
            def axes      = frames.map { _1[:axis] }             # semantic axis names (vector)
            def loop_ids  = frames.map { _1[:id] }               # unique ids for disambiguation
            def element_reg_for(axis) = frames.reverse.find { _1[:axis] == axis }&.dig(:as_element)
            def index_reg_for(axis)   = frames.reverse.find { _1[:axis] == axis }&.dig(:as_index)
            def push(frame) = frames << frame
            def pop         = frames.pop
            def depth       = frames.length
          end


          # Lower a single declaration.
          # Align Γ to the declaration's axes using a local anchor when present,
          # lower the body, then close all loops.
          # @param decl [NAST::Declaration]
          # @raise [RuntimeError] when no anchor can cover required axes
          def lower_declaration(decl)
            wanted = axes_of(decl)
          
            if wanted.empty?
              # scalar decl: no loops to open
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
            when NAST::Reduce   then emit_reduce(node)
            when NAST::Call     then emit_call(node) # defensive; SNAST should have rewritten builtins
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
            ins = Build.make_tuple(elements: regs, out_dtype: dtype_of(n), ids: @ids)
            @ops << ins
            ins.result_register
          end

          def emit_call(n)
            if @registry.function_select?(n.fn)
              sel = NAST::Select.new(id: n.id, cond: n.args[0], on_true: n.args[1], on_false: n.args[2], loc: n.loc, meta: n.meta)
              return emit_select(sel)
            end
            if @registry.function_reduce?(n.fn)
              red = NAST::Reduce.new(id: n.id, op_id: n.fn, over: [], arg: n.args.first, loc: n.loc, meta: n.meta)
              return emit_reduce(red)
            end
            regs = n.args.map { lower_expr(_1) }
            ins  = Build.kernel_call(function: @registry.resolve_function(n.fn), args: regs, out_dtype: dtype_of(n), ids: @ids)
            @ops << ins
            ins.result_register
          end

          def emit_select(n)
            # context must already equal axes_of(n)
            ensure_context_for!(axes_of(n), anchor: n)
            c = lower_expr(n.cond)
            t = lower_expr(n.on_true)
            f = lower_expr(n.on_false)
            ins = Build.select(cond: c, on_true: t, on_false: f, out_dtype: dtype_of(n), ids: @ids)
            @ops << ins
            ins.result_register
          end

          # Lower a Reduce node.
          # Validates axes, aligns Γ to out_axes, opens `over`, performs
          # declare/accumulate/close/load.
          # @param n [NAST::Reduce]
          # @return [Symbol] result register holding the reduced value
          # @raise [RuntimeError] on scalar input or axes mismatch
          def emit_reduce(n)
            debug "emit_reduce: starting with #{n.class.name}, op_id=#{n.op_id}"
            out_axes = axes_of(n)
            in_axes  = axes_of(n.arg)
            debug "emit_reduce: out_axes=#{out_axes.inspect}, in_axes=#{in_axes.inspect}, over=#{Array(n.over).inspect}"
            debug "emit_reduce: arg is #{n.arg.class.name}"
            raise "reduce: scalar input" if in_axes.empty?
            raise "reduce: axes(arg)=#{in_axes} must equal out+over" unless in_axes == out_axes + Array(n.over)

            # 1) Align to Γ
            ensure_context_for!(out_axes, anchor: n.arg)

            # 2) Declare accumulator at Γ
            dtype    = dtype_of(n)
            acc_name = @ids.generate_temp(prefix: :acc_)
            init     = identity_literal(n.op_id, dtype)
            @ops << Build.declare_accumulator(name: acc_name, initial: init)

            # 3) Open `over` loops and accumulate inside
            open_suffix_loops!(over_axes: Array(n.over), anchor: n.arg)
            val = lower_expr(n.arg)
            @ops << Build.accumulate(
              accumulator: acc_name,
              function:    @registry.resolve_function(n.op_id),
              value_register: val
            )

            # 4) Close `over` and load at Γ
            close_loops_to_depth(out_axes.length)
            ins = Build.load_accumulator(name: acc_name, dtype: dtype, ids: @ids)
            @ops << ins
            ins.result_register
          end

          # ---------- InputRef lowering ----------

          # Lower an InputRef path to a register.
          # Starts from the deepest open axis token present in the path or from root.
          # Emits LoadInput and LoadField as needed. Reuses element registers when the
          # path traverses an already-open loop axis.
          # @param n [NAST::InputRef]
          # @return [Symbol] register containing the addressed value/collection
          def emit_input_ref(n)
            toks = n.path
            base_ix = deepest_open_axis_index_in_path(toks)
            if base_ix
              cur = @env.element_reg_for(toks[base_ix])
              i = base_ix + 1
            else
              cur = Build.load_input(key: toks.first, dtype: :array, ids: @ids).tap { @ops << _1 }.result_register
              i = 1
            end

            while i < toks.length
              tok = toks[i]
              if @env.axes.include?(tok)
                cur = @env.element_reg_for(tok)
              else
                is_last = (i == toks.length - 1)
                field_dtype = is_last ? dtype_of(n) : :array
                cur = Build.load_field(object_register: cur, key: tok, dtype: field_dtype, ids: @ids).tap { @ops << _1 }.result_register
              end
              i += 1
            end
            cur
          end

          # ---------- context management ----------

          # Ensure Γ equals the target axes.
          # Closes loops down to LCP(Γ,target), then opens the missing suffix.
          # @param target_axes [Array<Symbol>]
          # @param anchor [NAST::Node,nil] subtree used to prefer a local carrier
          # @raise [RuntimeError] if missing suffix exists and no anchor is available
          def ensure_context_for!(target_axes, anchor:)
            # close extra frames down to LCP
            l = lcp(@env.axes, target_axes).length
            close_loops_to_depth(l)
          
            missing = target_axes[l..] || []
            return if missing.empty?         # nothing to open; works for target_axes == []
          
            raise "need anchor InputRef to open loops for #{missing.inspect}" unless anchor
            open_suffix_loops!(over_axes: missing, anchor:)
          end
          
          # Open suffix loops deterministically.
          # Chooses a carrier path tokens sequence, builds collection registers for each
          # depth, emits LoopStart for each axis, and pushes frames into Γ.
          # Preference: exact local anchor tokens for the target axes, else module carrier.
          # @param over_axes [Array<Symbol>]
          # @param anchor [NAST::Node,nil]
          # @raise [KeyError,RuntimeError] if carrier selection fails
          def open_suffix_loops!(over_axes:, anchor:)
            return if over_axes.empty?
          
            target       = @env.axes + over_axes
            local_tokens = anchor_path(anchor) if anchor
            tokens       = choose_carrier_for_axes(target_axes: target, local_tokens:)
            base         = @env.axes.length
          
            need = base + over_axes.length + 1
            raise "carrier tokens too short for #{target.inspect}" if tokens.length < need
          
            over_axes.each_with_index do |ax, i|
              open_depth = base + i
          
              coll =
                if open_depth.zero?
                  Build.load_input(key: tokens.first, dtype: :array, ids: @ids).tap { @ops << _1 }.result_register
                else
                  prev_axis = target[open_depth - 1]
                  src_el    = @env.element_reg_for(prev_axis) || raise("no element for #{prev_axis}")
                  key_tok   = tokens[open_depth]
                  Build.load_field(object_register: src_el, key: key_tok, dtype: :array, ids: @ids).tap { @ops << _1 }.result_register
                end
          
              el     = @ids.generate_temp(prefix: :"#{ax}_el_")
              ix     = @ids.generate_temp(prefix: :"#{ax}_i_")
              loop_id = @ids.generate_loop_id
              @ops << Build.loop_start(collection_register: coll, axis: ax, as_element: el, as_index: ix, id: loop_id)
              @env.push(axis: ax, as_element: el, as_index: ix, id: loop_id)
            end
          end
          
          def close_loops_to_depth(depth)
            while @env.depth > depth
              @env.pop
              @ops << Build.loop_end
            end
          end

          # path/chain helpers

          # Build collection registers along a carrier path.
          # Given canonical tokens [root, a0, a1, …] and a target axes prefix of length k,
          # emits LoadInput(root) then k LoadField steps, returning the k collection
          # registers (each is the collection for one axis depth).
          # @param path_tokens [Array<Symbol>]
          # @param axes_prefix [Array<Symbol>]
          # @return [Array<Symbol>] size == axes_prefix.length
          # @raise [RuntimeError] when path_tokens is nil
          def build_chain_to_axes(path_tokens, axes_prefix)
            debug "build_chain_to_axes: path_tokens=#{path_tokens.inspect}, axes_prefix=#{axes_prefix.inspect}"
            raise "build_chain_to_axes: path_tokens is nil" if path_tokens.nil?
            regs = []
            cur = Build.load_input(key: path_tokens.first, dtype: :array, ids: @ids).tap { @ops << _1 }.result_register
            regs << cur
            (1...axes_prefix.length).each do |idx|
              tok = path_tokens[idx]
              cur = Build.load_field(object_register: cur, key: tok, dtype: :array, ids: @ids).tap { @ops << _1 }.result_register
              regs << cur
            end
            regs
          end
            
          # Find a local InputRef carrier in a subtree.
          # Order: Select(on_true before on_false), Reduce(arg), Call/Tuple(args).
          # Returns tokens or nil when absent.
          # @param node [NAST::Node,nil]
          # @return [Array<Symbol>, nil] tokens like [:root, :axis0, :axis1, …]
          def anchor_path(node)
            debug "anchor_path: examining #{node.class.name}"
            result = case node
            when NAST::InputRef 
              debug "anchor_path: found InputRef with path #{node.path.inspect}"
              node.path
            when NAST::Select   
              debug "anchor_path: checking Select branches"
              anchor_path(node.on_true) || anchor_path(node.on_false)
            when NAST::Reduce   
              debug "anchor_path: checking Reduce arg"
              anchor_path(node.arg)
            when NAST::Call     
              debug "anchor_path: checking Call args"
              node.args.lazy.map { anchor_path(_1) }.find { _1 }
            when NAST::Tuple    
              debug "anchor_path: checking Tuple args"
              node.args.lazy.map { anchor_path(_1) }.find { _1 }
            else
              debug "anchor_path: no match for #{node.class.name}"
              nil
            end
            debug "anchor_path: result = #{result.inspect}"
            result or (debug("anchor_path: no anchorable InputRef found") && raise("no anchorable InputRef in subtree"))
          end

          def find_anchor_inputref(node, need_prefix:)
            found = nil
            walk = lambda do |x|
              case x
              when NAST::InputRef
                ax = axes_of(x)
                found ||= x if prefix?(need_prefix, ax)
              when NAST::Select
                walk.call(x.cond); walk.call(x.on_true); walk.call(x.on_false)
              when NAST::Reduce
                walk.call(x.arg)
              when NAST::Call, NAST::Tuple
                x.args.each { walk.call(_1) }
              end
            end
            walk.call(node)
            found or raise "no anchor InputRef covering axes #{need_prefix.inspect}"
          end

          def deepest_open_axis_index_in_path(tokens)
            idx = -1
            @env.axes.each do |ax|
              j = tokens.index(ax)
              idx = j if j && j > idx
            end
            idx >= 0 ? idx : nil
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

          def identity_literal(op_id, dtype)
            begin
              v = @registry.kernel_identity_for(op_id, dtype: dtype, target: :ruby)
              LIR::Literal.new(value: v, dtype: dtype)
            rescue
              zero = case dtype
                     when :integer then 0
                     when :float   then 0.0
                     else 0
                     end
              LIR::Literal.new(value: zero, dtype: dtype)
            end
          end

          # Choose carrier tokens for a target axes vector.
          # 1) If local_tokens exactly match the target axes, use them.
          # 2) Else take the canonical module-level carrier for that axes vector.
          # @param target_axes [Array<Symbol>]
          # @param local_tokens [Array<Symbol>, nil]
          # @return [Array<Symbol>] canonical tokens for the carrier path prefix
          # @raise [KeyError] when no module carrier exists
          def choose_carrier_for_axes(target_axes:, local_tokens:)
            # 1) Local subtree anchor if it exactly matches target axes
            if local_tokens
              cand = tokens_for_axes(target_axes, local_tokens)
              return cand if cand
            end
          
            # 2) Module-level strict carrier
            @carriers.fetch(target_axes) { raise "no carrier path for axes #{target_axes.inspect}" }
          end
          
          # Build a strict carrier map from the module.
          # For every InputRef with axes A=[a0,…,am], record tokens[0..k] for k=1..m
          # under key A[0..k-1]. Each key must have exactly one unique tokens value.
          # @param root [NAST::Module, NAST::Declaration]
          # @return [Hash{Array<Symbol> => Array<Symbol>}] { axes_vec => tokens_prefix }
          # @raise [RuntimeError] when ambiguities exist for any axes vector
          def build_carrier_map(root)
            # Collect candidates per axes vector
            buckets = Hash.new { |h, k| h[k] = [] }
          
            walk = lambda do |n|
              case n
              when NAST::Module
                n.decls.each_value { walk.call(_1) }
              when NAST::Declaration
                walk.call(n.body)
              when NAST::InputRef
                axes = Array(n.meta[:stamp]&.dig(:axes))
                toks = n.path.map!(&:to_sym)
                (1..axes.length).each do |k|
                  key = axes[0...k]
                  val = toks[0..k] # head + k fields
                  buckets[key] << val
                end
              when NAST::Select
                walk.call(n.cond); walk.call(n.on_true); walk.call(n.on_false)
              when NAST::Reduce
                walk.call(n.arg)
              when NAST::Call, NAST::Tuple
                n.args.each { walk.call(_1) }
              end
            end
            walk.call(root)
          
            # Strict: unique or error
            carriers = {}
            buckets.each do |key, arr|
              uniq = arr.uniq
              if uniq.length != 1
                alts = uniq.map { _1.map(&:to_s).join('.') }.sort
                raise "ambiguous carriers for axes #{key.inspect}: #{alts}"
              end
              carriers[key] = uniq.first
            end
            carriers
          end

          # Validate that a tokens path matches a target axes vector.
          # Returns the shortest prefix tokens[0..m] when tokens[1..m] equals target_axes.
          # Else nil.
          # @param target_axes [Array<Symbol>]
          # @param tokens [Array<Symbol>]
          # @return [Array<Symbol>, nil]
          def tokens_for_axes(target_axes, tokens)
            m = target_axes.length
            return nil unless tokens.length >= m + 1
            ok = (1..m).all? { |i| tokens[i].to_sym == target_axes[i - 1].to_sym }
            ok ? tokens[0..m] : nil
          end
        end
      end
    end
  end
end
