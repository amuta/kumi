# frozen_string_literal: true

module Kumi
  module IR
    module Loop
      # Lowers VecIR into execution-shaped LoopIR.
      #
      # Input contract (VecIR after VecValidatePass):
      # - one entry block per function, SSA registers
      # - every instruction stamped with axes and dtype
      # - load_input/load_field chains follow the DF access contract
      # - reduce over_axes are an innermost suffix of the argument axes
      #
      # Output contract (enforced by Loop::Validator):
      # - explicit loop_start/loop_end nests over axis carrier arrays
      # - reductions as acc_init/acc_step/acc_load
      # - axis_index as loop index registers
      # - axis_shift as shift_read with explicit policy
      # - vector values that escape their defining loop are materialized via
      #   array_init/array_push and read back with index_read
      class Lower
        def initialize(vec_module:, context: {})
          @vec_module = vec_module
          @context = context
        end

        def call
          plans = @context[:input_plans] || {}
          registry = @context[:registry]
          cross_axes = @context[:cross_axes] || {}
          outer_axes = @context[:outer_axes] || {}

          loop_module = Loop::Module.new(name: @vec_module.name)
          @vec_module.each_function do |vec_function|
            lowering = FunctionLowering.new(vec_function, plans: plans, registry: registry, cross_axes: cross_axes,
                                                          outer_axes: outer_axes)
            loop_module.add_function(lowering.call)
          end
          loop_module
        end

        # A loop nest under construction. Nodes are kept in a mutable tree so
        # materialization discovered later can still insert array_init/push
        # nodes at the right places.
        class LoopNode
          attr_reader :pre, :start, :body, :end_node
          attr_accessor :parent_body

          def initialize(start:, end_node:, parent_body:)
            @pre = []
            @start = start
            @body = []
            @end_node = end_node
            @parent_body = parent_body
          end
        end

        Instance = Struct.new(:axis, :elem, :idx, :node, keyword_init: true) do
          def body = node.body
        end

        DefSite = Struct.new(:node, :body, :loop_chain, :reg, keyword_init: true)
        PendingAcc = Struct.new(:vec_reg, :acc_reg, :instance, :dtype, keyword_init: true)

        class FunctionLowering
          ZERO_FILLS = { "integer" => 0, "float" => 0.0, "boolean" => false, "string" => "" }.freeze

          def initialize(vec_function, plans:, registry:, cross_axes: {}, outer_axes: {})
            @fn = vec_function
            @plans = plans
            @registry = registry
            @cross_axes = cross_axes || {}
            @outer_axes = outer_axes || {}

            @instrs = vec_function.blocks.flat_map(&:instructions)
            @by_reg = @instrs.each_with_object({}) { |i, h| h[i.result] = i if i.result }

            @top = []
            @stack = []
            @memo = Hash.new { |h, k| h[k] = {} }
            @def_sites = {}
            @materialized = {}
            @pending_accs = []
            @axis_table = build_axis_table

            @counter = next_reg_start
          end

          def call
            @instrs.each { |instr| lower_instruction(instr) }
            return_reg = emit_return
            close_all

            instructions = flatten(@top)
            block = Base::Block.new(name: :entry, instructions: instructions)
            Loop::Function.new(name: @fn.name, blocks: [block], return_reg: return_reg)
          end

          private

          # ---------------------------------------------------------------
          # instruction dispatch
          # ---------------------------------------------------------------

          def lower_instruction(instr)
            case instr.opcode
            when :constant, :load_input, :load_field, :axis_broadcast, :axis_index, :axis_outer
              nil # lazy: emitted at use sites
            when :map
              emit_simple(instr) do |args|
                Ops::KernelCall.new(result: instr.result, fn: instr.attributes[:fn], args: args,
                                    axes: instr.axes, dtype: instr.dtype)
              end
            when :select
              emit_simple(instr) do |args|
                Ops::Select.new(result: instr.result, cond: args[0], on_true: args[1], on_false: args[2],
                                axes: instr.axes, dtype: instr.dtype)
              end
            when :make_object
              emit_simple(instr) do |args|
                Ops::MakeObject.new(result: instr.result, inputs: args, keys: instr.attributes[:keys],
                                    axes: instr.axes, dtype: instr.dtype)
              end
            when :axis_shift
              lower_shift(instr)
            when :axis_cross
              lower_cross(instr)
            when :reduce
              lower_reduce(instr)
            else
              raise NotImplementedError, "LoopIR lowering does not handle #{instr.opcode.inspect}"
            end
          end

          def emit_simple(instr)
            resolve_pending_uses(instr.uses)
            align_nest(instr.axes)
            args = instr.uses.map { |r| read(r) }
            node = yield(args)
            emit(node)
            record_def(instr.result, node)
          end

          # ---------------------------------------------------------------
          # reduce
          # ---------------------------------------------------------------

          def lower_reduce(instr)
            arg = instr.uses.first
            over = Array(instr.attributes[:over_axes]).map(&:to_sym)
            arg_axes = axes_of(arg)
            out_axes = Array(instr.axes)

            unless arg_axes.last(over.size) == over && arg_axes[0...-over.size] == out_axes
              raise ArgumentError,
                    "LoopIR reduce expects over_axes #{over.inspect} to be the innermost suffix of #{arg_axes.inspect}"
            end

            resolve_pending_uses([arg])
            align_nest(arg_axes)
            value = read(arg)

            fn = instr.attributes[:fn]
            init, nil_init = reduction_init(fn, instr.dtype)
            acc = fresh(:acc)

            first_over = @stack[out_axes.size]
            first_over.node.pre << Ops::AccInit.new(result: acc, fn: fn, init: init, nil_init: nil_init,
                                                    dtype: instr.dtype)
            emit(Ops::AccStep.new(acc: acc, value: value, fn: fn, nil_init: nil_init))

            @pending_accs << PendingAcc.new(vec_reg: instr.result, acc_reg: acc, instance: first_over,
                                            dtype: instr.dtype)
          end

          # A reduction either has a true identity (seed the accumulator with it)
          # or none at all (seed from the first element via nil_init — e.g. min/max).
          #
          # A kernel that DECLARES an identity map but is missing an entry for the
          # reduction's dtype is a registry gap, not a license to fall back to
          # nil_init: that path silently double-counts the first element. Fail
          # loudly instead so a missing identity is a build bug, never a wrong
          # number.
          def reduction_init(fn, dtype)
            kernel = @registry&.kernel_for(fn, target: :ruby)
            identity = kernel&.identity
            return [nil, true] if identity.nil?

            key = dtype.to_s
            value = identity.fetch(key) { identity["any"] }
            if value.nil?
              raise Kumi::Core::Errors::CompilerBug,
                    "reduce #{fn} has an identity map but no identity for dtype #{dtype} " \
                    "(known: #{identity.keys.join(', ')})"
            end

            [value, false]
          end

          # ---------------------------------------------------------------
          # axis_shift
          # ---------------------------------------------------------------

          # Zero policy is decomposed into a clamped (always valid) read plus a
          # bounds check selecting the fill value, so the fill applies at the
          # element level even when the shifted axis is not innermost.
          def lower_shift(instr)
            src = instr.uses.first
            axes = Array(instr.axes)
            axis = instr.attributes[:axis].to_sym
            pos = axes.index(axis) or raise ArgumentError, "axis_shift axis #{axis} not in #{axes.inspect}"

            offset = instr.attributes[:offset]
            policy = instr.attributes[:policy].to_sym
            shift_info = {
              pos: pos,
              offset: offset,
              policy: policy == :zero ? :clamp : policy,
              dtype: instr.dtype
            }

            src = resolve_alias(src)
            src_instr = @by_reg[src]

            if load_chain?(src_instr)
              align_nest(axes)
              value = chain_read(src, shift: shift_info)
            else
              # The source must be fully collected along the shifted axis, so
              # close its loops down to the shift position before reading.
              site = @def_sites[src]
              close_one while site && shared_prefix_length(site.loop_chain) > pos
              ensure_materialized(src)
              align_nest(axes)
              value = materialized_shift_read(src, shift_info)
            end

            node =
              if policy == :zero
                in_bounds = fresh(:v)
                emit(Ops::ShiftInBounds.new(result: in_bounds, index: @stack[pos].idx,
                                            length: shift_info.fetch(:length_reg), offset: offset,
                                            dtype: :boolean))
                fill = fresh(:v)
                emit(Ops::Constant.new(result: fill, value: zero_fill(instr.dtype), axes: [], dtype: instr.dtype))
                Ops::Select.new(result: instr.result, cond: in_bounds, on_true: value, on_false: fill,
                                axes: axes, dtype: instr.dtype)
              else
                Ops::Ref.new(result: instr.result, value: value, axes: axes, dtype: instr.dtype)
              end
            emit(node)
            record_def(instr.result, node)
          end

          # axis_cross: result at (i, j) = source[j]. We open the nest to the
          # cross axes (introducing the inner cross loop) and read the source
          # load chain with its source-axis loop redirected to the cross loop's
          # index, so the value depends on j rather than i.
          def lower_cross(instr)
            src = instr.uses.first
            axes = Array(instr.axes)
            new_axis = instr.attributes[:axis].to_sym
            source_axis = instr.attributes[:source_axis].to_sym

            src = resolve_alias(src)
            src_instr = @by_reg[src]
            unless load_chain?(src_instr)
              raise ArgumentError, "cross currently supports input-backed sources only (got #{src_instr&.opcode.inspect})"
            end

            align_nest(axes)
            value = chain_read(src, cross: { source_axis: source_axis, new_axis: new_axis })

            node = Ops::Ref.new(result: instr.result, value: value, axes: axes, dtype: instr.dtype)
            emit(node)
            record_def(instr.result, node)
          end

          def materialized_shift_read(src, shift_info)
            pos = shift_info[:pos]
            site = @def_sites.fetch(src)
            arrays = @materialized.fetch(src)
            k = shared_prefix_length(site.loop_chain)
            raise ArgumentError, "axis_shift source #{src.inspect} is still collecting at the shift axis" if k > pos

            cur = arrays[k]
            (k...pos).each { |j| cur = emit_index_read(cur, @stack[j].idx) }
            cur = emit_shift_read(cur, shift_info)
            ((pos + 1)...axes_of(src).size).each { |j| cur = emit_index_read(cur, @stack[j].idx) }
            cur
          end

          def emit_shift_read(array, shift_info)
            len = emit_array_len(array)
            shift_info[:length_reg] = len
            shifted = fresh(:v)
            emit(Ops::ShiftRead.new(result: shifted, array: array, index: @stack[shift_info[:pos]].idx,
                                    length: len, offset: shift_info[:offset], policy: shift_info[:policy],
                                    dtype: shift_info[:dtype]))
            shifted
          end

          def zero_fill(dtype)
            ZERO_FILLS.fetch(dtype.to_s, 0)
          end

          # ---------------------------------------------------------------
          # return value
          # ---------------------------------------------------------------

          def emit_return
            last = @instrs.reverse.find(&:result) or raise ArgumentError, "LoopIR function has no result"
            ret = resolve_alias(last.result)
            axes = axes_of(ret)
            resolve_pending_uses([ret])

            if axes.empty?
              close_all
              return read(ret)
            end

            unless @def_sites.key?(ret)
              align_nest(axes)
              value = read(ret)
              node = Ops::Ref.new(result: fresh(:v), value: value, axes: axes, dtype: last.dtype)
              emit(node)
              record_def(node.result, node)
              ret = node.result
            end

            ensure_materialized(ret)
            close_all
            @materialized.fetch(ret).first
          end

          # ---------------------------------------------------------------
          # nest management
          # ---------------------------------------------------------------

          def align_nest(target_axes)
            target_axes = Array(target_axes)
            close_one while @stack.size > target_axes.size ||
                            @stack.map(&:axis) != target_axes.first(@stack.size)
            (@stack.size...target_axes.size).each { |d| open_axis(target_axes[d], d) }
          end

          def open_axis(axis, depth)
            info = @axis_table[axis] or raise ArgumentError, "LoopIR has no carrier for axis #{axis.inspect}"

            if %i[cross outer].include?(info[:kind])
              # Re-iterate a carrier under a fresh index, independent of the
              # enclosing element. For :cross that carrier is the surrounding
              # array itself (A x A'); for :outer it's a different root array
              # (A x B). Either way it opens as a new innermost loop.
              source = emit_nav_path(info[:head_path])
            elsif info[:parent].nil?
              raise ArgumentError, "axis #{axis} carrier expects depth 0" unless depth.zero?

              source = emit_nav_path(info[:head_path])
            else
              parent = @stack.last
              unless parent && parent.axis == info[:parent]
                raise ArgumentError,
                      "axis #{axis} carrier expects parent #{info[:parent].inspect}, open: #{@stack.map(&:axis).inspect}"
              end
              source = emit_field_path(parent.elem, info[:between])
            end

            elem = fresh(:"#{axis}_el")
            idx = fresh(:"#{axis}_i")
            start = Ops::LoopStart.new(result: elem, source: source, axis: axis, index: idx)
            node = LoopNode.new(start: start, end_node: Ops::LoopEnd.new(axis: axis), parent_body: current_body)
            current_body << node
            @stack.push(Instance.new(axis: axis, elem: elem, idx: idx, node: node))
          end

          def close_one
            instance = @stack.pop
            flushed, @pending_accs = @pending_accs.partition { |p| p.instance.equal?(instance) }
            flushed.each do |pending|
              node = Ops::AccLoad.new(result: pending.vec_reg, acc: pending.acc_reg, dtype: pending.dtype)
              emit(node)
              record_def(pending.vec_reg, node)
            end
          end

          def close_all
            close_one until @stack.empty?
          end

          def current_body
            @stack.empty? ? @top : @stack.last.body
          end

          def emit(node)
            current_body << node
            node
          end

          def record_def(reg, node)
            @def_sites[reg] = DefSite.new(node: node, body: current_body, loop_chain: @stack.dup, reg: reg)
          end

          # Close any open loops whose pending reductions feed the given uses,
          # so acc_load results exist before they are read.
          def resolve_pending_uses(uses)
            uses.each do |use|
              use = resolve_alias(use)
              pending = @pending_accs.find { |p| p.vec_reg == use }
              next unless pending

              close_one while @stack.include?(pending.instance)
            end
          end

          # ---------------------------------------------------------------
          # reads
          # ---------------------------------------------------------------

          def resolve_alias(reg)
            instr = @by_reg[reg]
            while instr && instr.opcode == :axis_broadcast
              reg = instr.uses.first
              instr = @by_reg[reg]
            end
            reg
          end

          def read(reg)
            reg = resolve_alias(reg)
            instr = @by_reg[reg]

            return read_computed(reg) if @def_sites.key?(reg)

            case instr&.opcode
            when :constant
              memoized([:constant, reg]) do
                node = Ops::Constant.new(result: fresh(:v), value: instr.attributes[:value],
                                         axes: [], dtype: instr.dtype)
                emit(node)
                node.result
              end
            when :load_input, :load_field
              chain_read(reg)
            when :axis_outer
              # Read the OTHER array's element at the (already-open) outer loop's
              # index. The surrounding nest is open by the consumer, so the value
              # varies over the inner pairing axis as intended.
              new_axis    = instr.attributes[:axis].to_sym
              source_axis = instr.attributes[:source_axis].to_sym
              src = resolve_alias(instr.uses.first)
              chain_read(src, cross: { source_axis: source_axis, new_axis: new_axis })
            when :axis_index
              axis = instr.attributes[:axis].to_sym
              instance = @stack.find { |i| i.axis == axis } or
                raise ArgumentError, "axis_index #{axis} read outside its loop"
              instance.idx
            else
              raise ArgumentError, "LoopIR cannot read #{reg.inspect} (#{instr&.opcode.inspect})"
            end
          end

          # Reads a value defined in a loop instance that is no longer fully
          # open. Arrays for still-open shared levels are incomplete, so the
          # read starts from the deepest shared level's array (a live local
          # that finished collecting when the diverging loop closed).
          def read_computed(reg)
            site = @def_sites.fetch(reg)
            return reg if live?(site)

            ensure_materialized(reg)
            arrays = @materialized.fetch(reg)
            k = shared_prefix_length(site.loop_chain)
            cur = arrays[k]
            (k...site.loop_chain.size).each do |j|
              cur = emit_index_read(cur, index_for_level(site.loop_chain[j]))
            end
            cur
          end

          # The materialized arrays are nested in the def site's loop_chain axis
          # order, which need not match the consumer's open-stack order (an
          # `outer`/`cross` value defined over a single inner axis can be read
          # inside a wider nest that opens other axes first). Index each level by
          # the currently-open instance whose axis matches that def-chain level,
          # not by positional depth.
          def index_for_level(def_instance)
            return def_instance.idx if @stack.any? { |i| i.equal?(def_instance) }

            match = @stack.find { |i| i.axis == def_instance.axis } or
              raise ArgumentError,
                    "LoopIR cannot read value defined over axis #{def_instance.axis.inspect}: " \
                    "no open loop for it (open: #{@stack.map(&:axis).inspect})"
            match.idx
          end

          def shared_prefix_length(chain)
            k = 0
            k += 1 while k < chain.size && @stack[k]&.equal?(chain[k])
            k
          end

          def live?(site)
            site.loop_chain.each_with_index.all? { |inst, i| @stack[i]&.equal?(inst) }
          end

          # ---------------------------------------------------------------
          # materialization
          # ---------------------------------------------------------------

          def ensure_materialized(reg)
            return if @materialized.key?(reg)

            site = @def_sites.fetch(reg) do
              raise ArgumentError, "LoopIR cannot materialize #{reg.inspect}: no definition site"
            end
            depth = site.loop_chain.size
            raise ArgumentError, "LoopIR cannot materialize scalar #{reg.inspect}" if depth.zero?

            arrays = (0...depth).map { fresh(:arr) }
            (0...depth).each { |j| site.loop_chain[j].node.pre << Ops::ArrayInit.new(result: arrays[j]) }

            insert_after(site.body, site.node, Ops::ArrayPush.new(array: arrays[depth - 1], value: reg))
            (1...depth).each do |j|
              loop_node = site.loop_chain[j].node
              insert_after(loop_node.parent_body, loop_node, Ops::ArrayPush.new(array: arrays[j - 1], value: arrays[j]))
            end

            @materialized[reg] = arrays
          end

          def insert_after(body, node, new_node)
            index = body.index { |n| n.equal?(node) } or
              raise ArgumentError, "LoopIR lost track of a definition site"
            body.insert(index + 1, new_node)
          end

          # ---------------------------------------------------------------
          # input chains
          # ---------------------------------------------------------------

          def load_chain?(instr)
            instr && %i[load_input load_field].include?(instr.opcode)
          end

          def chain_segments(reg)
            segments = []
            instr = @by_reg[reg]
            while instr
              case instr.opcode
              when :load_field
                segments.unshift(instr.attributes[:field].to_s)
                instr = @by_reg[instr.uses.first]
              when :load_input
                segments.unshift(instr.attributes[:key].to_s)
                instr = nil
              else
                raise ArgumentError, "LoopIR load chain contains #{instr.opcode.inspect}"
              end
            end
            segments
          end

          # Walks a load chain's input plan against the currently open loops.
          # Loop consumption is capped by the register's own axes: a chain
          # stamped with fewer axes than the plan has loops reads the carrier
          # array itself rather than its elements.
          # With `shift:`, the loop at `shift[:pos]` is read at a shifted index
          # instead of through its open element register.
          def chain_read(reg, shift: nil, cross: nil)
            fqn = chain_segments(reg).join(".")
            plan = @plans[fqn] or raise ArgumentError, "LoopIR access contract missing input plan for #{fqn.inspect}"

            limit = axes_of(reg).size
            cur = nil
            depth = 0
            keys_after_loop = []

            plan[:steps].each do |step|
              case step[:kind].to_s
              when "property_access"
                keys_after_loop << step[:key].to_sym
              when "element_access"
                nil
              when "array_loop"
                break if depth == limit

                if cross && step[:axis].to_sym == cross[:source_axis]
                  # Read the source array at the independent cross index instead
                  # of the enclosing source-axis index.
                  instance = @stack.find { |i| i.axis == cross[:new_axis] } or
                    raise ArgumentError, "LoopIR cross loop #{cross[:new_axis].inspect} not open"
                  cur = instance.elem
                elsif shift && depth == shift[:pos]
                  array = resolve_chain_keys(cur, keys_after_loop, depth)
                  cur = emit_shift_read(array, shift)
                elsif shift && depth > shift[:pos]
                  array = resolve_chain_keys(cur, keys_after_loop, depth)
                  cur = emit_index_read(array, @stack[depth].idx)
                else
                  instance = @stack[depth]
                  step_axis = step[:axis].to_sym
                  unless instance && instance.axis == step_axis
                    raise ArgumentError,
                          "LoopIR chain #{fqn} expects loop #{step_axis.inspect} at depth #{depth}, " \
                          "open: #{@stack.map(&:axis).inspect}"
                  end
                  cur = instance.elem
                end
                keys_after_loop = []
                depth += 1
              else
                raise ArgumentError, "LoopIR cannot handle plan step #{step[:kind].inspect}"
              end
            end

            resolve_chain_keys(cur, keys_after_loop, depth)
          end

          # Resolves trailing property keys from `base` (nil means input root).
          def resolve_chain_keys(base, keys, _depth)
            if base.nil?
              raise ArgumentError, "LoopIR chain read expects a root key" if keys.empty?

              base = emit_load_input(keys.first)
              keys = keys[1..]
            end
            keys.reduce(base) { |obj, key| emit_load_field(obj, key) }
          end

          def emit_nav_path(path)
            cur = nil
            Array(path).each do |kind, key|
              cur = case kind.to_sym
                    when :input then emit_load_input(key)
                    when :field then emit_load_field(cur, key)
                    else raise ArgumentError, "unknown nav step #{kind.inspect}"
                    end
            end
            cur
          end

          def emit_field_path(base, keys)
            Array(keys).reduce(base) { |obj, key| emit_load_field(obj, key) }
          end

          # ---------------------------------------------------------------
          # memoized primitive emissions
          # ---------------------------------------------------------------

          def emit_load_input(key)
            memoized([:input, key.to_sym]) do
              node = Ops::LoadInput.new(result: fresh(:v), key: key)
              emit(node)
              node.result
            end
          end

          def emit_load_field(object, field)
            memoized([:field, object, field.to_sym]) do
              node = Ops::LoadField.new(result: fresh(:v), object: object, field: field)
              emit(node)
              node.result
            end
          end

          def emit_index_read(array, index)
            memoized([:index_read, array, index]) do
              node = Ops::IndexRead.new(result: fresh(:v), array: array, index: index)
              emit(node)
              node.result
            end
          end

          def emit_array_len(array)
            memoized([:array_len, array]) do
              node = Ops::ArrayLen.new(result: fresh(:v), array: array)
              emit(node)
              node.result
            end
          end

          def memoized(key)
            body_memo = @memo[current_body.object_id]
            body_memo[key] ||= yield
          end

          # ---------------------------------------------------------------
          # helpers
          # ---------------------------------------------------------------

          def axes_of(reg)
            instr = @by_reg[resolve_alias(reg)] || @by_reg[reg]
            return Array(instr.axes) if instr

            raise ArgumentError, "unknown register #{reg.inspect}"
          end

          # Maps each axis to its carrier navigation, taken solely from the
          # input plans. DFIR import inlining already canonicalized axis names
          # to the caller's plan names, so instruction stamps and plan axes
          # agree by contract.
          def build_axis_table
            table = {}

            @plans.each_value do |plan|
              axes = Array(plan[:loop_axes]).map(&:to_sym)
              loop_ixs = Array(plan[:loop_ixs])

              axes.each_with_index do |axis, j|
                li = loop_ixs[j]
                entry =
                  if j.zero?
                    { parent: nil, head_path: plan[:head_path_by_loop][li] }
                  else
                    { parent: axes[j - 1], between: plan[:between_loops][[loop_ixs[j - 1], li]] }
                  end
                existing = table[axis]
                raise ArgumentError, "LoopIR found conflicting carriers for axis #{axis.inspect}" if existing && existing != entry

                table[axis] = entry
              end
            end

            # Cross axes re-iterate an existing carrier under a fresh index. They
            # share their source axis's carrier (its head_path) but open as a new
            # innermost loop, independent of the parent element.
            #
            # The child->source mapping is read straight off the axis_cross ops in
            # this function, not an external side-table — so a cross that arrived
            # via import inlining (where the caller never analyzed it) is handled
            # exactly like a local one. The analyzer-supplied @cross_axes is
            # merged as a fallback for any op the scan can't see.
            cross_sources = @cross_axes.dup
            @instrs.each do |instr|
              next unless instr.opcode == :axis_cross

              child = instr.attributes[:axis]&.to_sym
              source = instr.attributes[:source_axis]&.to_sym
              cross_sources[child] = source if child && source
            end

            cross_sources.each do |child_axis, source_axis|
              src = table[source_axis] or
                raise ArgumentError,
                      "LoopIR cross axis #{child_axis.inspect} has no carrier for source #{source_axis.inspect} " \
                      "(open axes: #{table.keys.inspect})"
              head_path = src[:head_path] or
                raise ArgumentError, "LoopIR cross axis #{child_axis.inspect} only supports root-array sources for now"

              table[child_axis] = { kind: :cross, source_axis: source_axis, head_path: head_path }
            end

            # Outer axes re-iterate a DIFFERENT array's carrier as a fresh inner
            # loop (the A x B pairing). Carrier is the other root array's own
            # head_path rather than the surrounding axis's.
            outer_sources = @outer_axes.dup
            @instrs.each do |instr|
              next unless instr.opcode == :axis_outer

              child = instr.attributes[:axis]&.to_sym
              source = instr.attributes[:source_axis]&.to_sym
              outer_sources[child] = source if child && source
            end

            outer_sources.each do |child_axis, source_axis|
              src = table[source_axis] or
                raise ArgumentError,
                      "LoopIR outer axis #{child_axis.inspect} has no carrier for source #{source_axis.inspect} " \
                      "(open axes: #{table.keys.inspect})"
              head_path = src[:head_path] or
                raise ArgumentError, "LoopIR outer axis #{child_axis.inspect} only supports root-array sources for now"

              table[child_axis] = { kind: :outer, source_axis: source_axis, head_path: head_path }
            end

            table
          end

          def next_reg_start
            max = @instrs.flat_map { |i| [i.result, *i.uses] }.compact
                         .filter_map { |r| r.to_s[/\Av(\d+)\z/, 1]&.to_i }.max
            (max || 0) + 1
          end

          def fresh(prefix)
            reg = :"#{prefix}#{@counter}"
            @counter += 1
            reg
          end

          # ---------------------------------------------------------------
          # tree flattening
          # ---------------------------------------------------------------

          def flatten(nodes, out = [])
            nodes.each do |node|
              if node.is_a?(LoopNode)
                flatten(node.pre, out)
                out << node.start
                flatten(node.body, out)
                out << node.end_node
              else
                out << node
              end
            end
            out
          end
        end
      end
    end
  end
end
