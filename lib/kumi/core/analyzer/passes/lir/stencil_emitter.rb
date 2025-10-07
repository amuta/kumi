# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        module LIR
          module StencilEmitter
            NAST = Kumi::Core::NAST

            def emit_roll(n)  = emit_stencil(:roll, n)
            def emit_shift(n) = emit_stencil(:shift, n)

            private

            def emit_stencil(kind, n)
              base_ir, offsets, policies = resolve_shift_chain(n)
              axes = axes_of(base_ir)
              raise "#{kind}: source has no axes" if axes.empty?

              anchor_fqn = anchor_fqn_from_node!(base_ir, need_prefix: axes)
              pre        = @pre.fetch(anchor_fqn) { raise "no precomputed plan for #{anchor_fqn}" }

              gather_with_offsets(base_ir, pre, offsets, policies)
            end

            def resolve_shift_chain(node)
              offsets  = Hash.new(0)
              policies = {}
              cur = node

              loop do
                case cur
                when NAST::Call
                  break unless %i[shift roll].include?(cur.fn)

                  src, off_node = cur.args
                  axes     = axes_of(src)
                  defaults = @registry.function(cur.fn)[:options] || {}
                  opts     = merge_call_opts(cur, defaults)
                  explicit = opts[:policy]
                  policy   = (if explicit
                                explicit.to_sym
                              else
                                (cur.fn == :roll ? :wrap : :wrap)
                              end)
                  aoff     = Integer(opts.fetch(:axis_offset, 0))
                  axis     = axes.fetch(axes.length - 1 - aoff) { raise "stencil: axis_offset out of range" }
                  offsets[axis]  += literal_offset!(off_node)
                  policies[axis]  = policy
                  cur = src
                when NAST::Ref
                  decl = @snast.decls.fetch(cur.name) { raise "unknown decl #{cur.name}" }
                  cur = decl.body
                else
                  break
                end
              end

              base_ir =
                case cur
                when NAST::InputRef then cur
                when NAST::Call, NAST::Ref then raise "stencil base must be InputRef after collapsing"
                else raise "unsupported stencil base #{cur.class}"
                end

              [base_ir, offsets, policies]
            end

            def gather_with_offsets(src_ir, pre, offsets, policies)
              src_axes  = axes_of(src_ir)
              steps     = pre[:steps]
              loop_ixs  = pre[:loop_ixs]
              loop_idx  = lambda { |ax|
                begin
                  loop_ixs[loop_ixs.index { |i| steps[i][:axis].to_sym == ax } ]
                rescue StandardError
                  (raise "plan lacks axis #{ax.inspect}")
                end
              }

              # start at head collection for first src axis
              first_ax = src_axes.first
              li       = loop_idx.call(first_ax)
              coll     = @env.collection_reg_for(first_ax) || head_collection(pre, li)

              ok_mask  = nil
              prev_li  = li
              cur      = nil

              src_axes.each_with_index do |ax, k|
                li = loop_idx.call(ax)
                # walk between loops from the previous axis to this axis on current object
                coll = between_loops(pre, prev_li, li, coll) if k > 0
                prev_li = li

                # choose index and policy for this axis
                i0  = @env.index_reg_for(ax) or raise "no index for #{ax}"
                off = offsets.fetch(ax, 0)
                n   = length_of(coll)
                j   = off.zero? ? i0 : @emit.sub_i(i0, @emit.iconst(off))

                pol = policies[ax] || :wrap # roll defaults to wrap
                jg  =
                  case pol
                  when :wrap
                    @emit.mod_i(@emit.add_i(@emit.mod_i(j, n), n), n)
                  when :clamp
                    hi = @emit.sub_i(n, @emit.iconst(1))
                    @emit.clamp(j, @emit.iconst(0), hi, out: :integer)
                  when :zero
                    ge0 = @emit.ge(j, @emit.iconst(0))
                    ltN = @emit.lt(j, n)
                    ok  = @emit.and_(ge0, ltN)
                    ok_mask = ok_mask ? @emit.and_(ok_mask, ok) : ok
                    hi = @emit.sub_i(n, @emit.iconst(1))
                    @emit.clamp(j, @emit.iconst(0), hi, out: :integer)
                  else
                    raise "unknown stencil policy #{pol.inspect}"
                  end

                # gather for this axis, then proceed
                last   = (k == src_axes.length - 1)
                out_dt = last ? dtype_of(src_ir) : :any
                cur    = @emit.gather(coll, jg, out_dt)

                # next axis will start from the object we just gathered
                coll = cur
              end

              if ok_mask
                z = @emit.const(0, dtype_of(src_ir))
                @emit.select(ok_mask, cur, z, dtype_of(src_ir))
              else
                cur
              end
            end

            # def neighbor_leaf_at(src:, src_axes:, at_axis:, pre:, liA:, collA:, jA:, safe_first_hop: false)
            #   mkey = [at_axis, jA.object_id, safe_first_hop, collA.object_id]
            #   if (cached = @env.memo_get(:neighbor, mkey))
            #     return cached[:leaf]
            #   end

            #   a_pos = src_axes.index(at_axis) or raise "axis #{at_axis} not in #{src_axes.inspect}"
            #   first_dtype = a_pos == src_axes.length - 1 ? dtype_of(src) : :any

            #   j0  = safe_first_hop ? jA : clamped_index(jA, collA)
            #   cur = @emit.gather(collA, j0, first_dtype)

            #   prev_li = liA
            #   (a_pos + 1).upto(src_axes.length - 1) do |k|
            #     ax  = src_axes[k]
            #     li  = loop_index_for_axis(pre, ax)
            #     cur = between_loops(pre, prev_li, li, cur)

            #     idx  = @env.index_reg_for(ax) or raise "no index for #{ax}"
            #     cur  = @emit.gather(cur, clamped_index(idx, cur), k == src_axes.length - 1 ? dtype_of(src) : :any)

            #     prev_li = li
            #   end

            #   @env.memo_set(:neighbor, mkey, { leaf: cur })
            #   cur
            # end

            # def loop_index_for_axis(pre, axis)
            #   steps     = pre[:steps]
            #   loop_ixs  = pre[:loop_ixs]
            #   loop_axes = loop_ixs.map { |i| steps[i][:axis].to_sym }
            #   j = loop_axes.index(axis) or raise "plan lacks axis #{axis.inspect}"
            #   loop_ixs[j]
            # end

            # def last_prior_env_axis_in_plan(pre, axis)
            #   in_plan    = pre[:loop_ixs].map { |i| pre[:steps][i][:axis].to_sym }
            #   target_pos = in_plan.index(axis)
            #   return nil unless target_pos

            #   @env.axes.reverse.find { |ax| (pos = in_plan.index(ax)) && pos < target_pos }
            # end

            # # ---- math helpers ----

            # def shifted_index(kind, policy, idx, off, nlen)
            #   case policy
            #   when :wrap
            #     i1 = @emit.add_i(idx, @emit.iconst(off))
            #     m1 = @emit.mod_i(i1, nlen)
            #     @emit.mod_i(@emit.add_i(m1, nlen), nlen)
            #   when :clamp
            #     j  = @emit.add_i(idx, @emit.iconst(off))
            #     hi = @emit.sub_i(nlen, @emit.iconst(1))
            #     @emit.clamp(j, @emit.iconst(0), hi, out: :integer)
            #   when :zero
            #     @emit.add_i(idx, @emit.iconst(off))
            #   else
            #     kind == :roll ? shifted_index(kind, :wrap, idx, off, nlen) : raise("#{kind}: unknown policy #{policy.inspect}")
            #   end
            # end

            # TODO : fix call node.opts being {opts: {}} or just flat keys, make always flat keys
            def merge_call_opts(call_node, defaults)
              raw = call_node.opts || {}
              # unwrap common nesting: {opts: {...}}
              raw = raw[:opts] if raw.key?(:opts)

              # normalize keys
              co = raw.each_with_object({}) { |(k, v), h| h[(k.respond_to?(:to_sym) ? k.to_sym : k)] = v }

              pol = (co.key?(:policy) ? co[:policy] : defaults[:policy])
              aof = (co.key?(:axis_offset) ? co[:axis_offset] : (defaults[:axis_offset] || 0))

              {
                policy: pol.to_sym,
                axis_offset: Integer(aof)
              }
            end

            def literal_offset!(node)
              v = node.is_a?(NAST::Const) ? node.value : nil
              raise "stencil offset must be integer literal" unless v.is_a?(Integer)

              v
            end

            def resolve_call(node)
              case node
              when NAST::Call
                node
              when NAST::Ref
                decl = @snast.decls.fetch(node.name) { return nil }
                resolve_call(decl.body)
              else
                nil
              end
            end
          end
        end
      end
    end
  end
end
