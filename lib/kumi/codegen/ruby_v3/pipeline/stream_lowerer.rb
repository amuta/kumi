# frozen_string_literal: true

require "set"

module Kumi
  module Codegen
    module RubyV3
      module Pipeline
        module StreamLowerer
          CGIR = Kumi::Codegen::RubyV3::CGIR
          module_function

          def run(view, ctx, consts:, deps:, identities:, producer_cache: {})
            ops  = []
            rank = ctx[:axes].length

            # Loops to open for this decl (already includes any extra reduce axes chosen in planning)
            axis_steps = view.axis_loops_for_decl(ctx[:name], producer_cache: producer_cache)

            # Positive-depth clamp for runtime sites; allow negative for global prelude
            physical_max = [axis_steps.length - 1, 0].max
            clamp_pos    = ->(d) { [[d, 0].max, physical_max].min }

            # Map op id → logical scheduled depth
            depth_of = {}
            ctx[:site_schedule].fetch("by_depth").each do |dinfo|
              d = dinfo.fetch("depth")
              dinfo.fetch("ops").each { |o| depth_of[o.fetch("id")] = d }
            end

            # Finalized reduce plans (placement-filled); keys may be strings or symbols
            rps = ctx[:reduce_plans_by_id] || {}
            key = ->(h, k) { h[k] || h[k.to_s] }

            # 1) Open loops
            axis_steps.each do |st|
              push!(ops, CGIR::Op.open_loop(
                depth: st["loop_idx"], step_kind: st["kind"], key: (st["kind"] == "array_field" ? st["key"] : nil)
              ))
            end

            # 2) Emit explicit accumulator initializations at reset sites (parent/group level)
            rps.each_value do |rp|
              red_id  = key[rp, :op_id]
              init    = identities.fetch(key[rp, :reducer_fn])
              reset_d = key[rp, :reset_depth]
              # Explicit init line so generated Ruby shows `acc_X = <id>` at the correct (parent) level.
              push!(ops, emit(code: "#{acc(red_id)} = #{literal(init)}",
                              depth: reset_d, phase: :pre,
                              defines: [acc(red_id)], uses: []))
            end

            # 3) Prelude consts at scheduled depths
            const_preludes(consts, ctx[:site_schedule]).each do |(code, d, cid)|
              push!(ops, emit(code: code, depth: clamp_pos.call(d), phase: :pre, defines: [c(cid)], uses: [], op_type: :const_prelude))
            end

            hoisted_const_ids = Set.new((ctx[:site_schedule]["hoisted_scalars"] || []).select { |s| s["kind"] == "const" }.map { |s| s["id"] })
            hoisted_all_ids   = Set.new((ctx[:site_schedule]["hoisted_scalars"] || []).map { |s| s["id"] })

            # 4) Scheduled ops → CGIR
            ctx[:site_schedule].fetch("by_depth").each do |dinfo|
              logical_d = dinfo.fetch("depth")
              dinfo.fetch("ops").each do |sched|
                ir = ctx[:ops].find { |o| o["id"] == sched["id"] }
                d  = hoisted_all_ids.include?(ir["id"]) ? logical_d : clamp_pos.call(logical_d)

                case sched["kind"]
                when "loadinput"
                  path = ir.fetch("args").first
                  expr = input_expr_for_path(view, path, axis_steps.length)
                  push!(ops, emit(code: "v#{ir['id']} = #{expr}", depth: d, defines: [v(ir["id"])], uses: []))

                when "const"
                  next if consts[:inline_ids].include?(ir["id"]) || hoisted_const_ids.include?(ir["id"])
                  val = ir.fetch("args").first
                  const_name = "c#{ctx[:name]}_#{ir['id']}"
                  push!(ops, emit(code: "#{const_name} = #{literal(val)}", depth: d, defines: [const_name], uses: []))

                when "map"
                  inline_needed_before!(ops, ir.fetch("args"), d, ctx:, view:, consts:, deps:, producer_cache:, axis_steps:)
                  args_syms = uses_for_args(ir["args"], consts, deps, ctx: ctx)
                  fn = ir.fetch("attrs").fetch("fn")
                  push!(ops, emit(code: "v#{ir['id']} = __call_kernel__(#{fn.inspect}, #{ir['args'].map { |a| ref(a, consts, deps, ctx: ctx) }.join(', ')})",
                                  depth: d, defines: [v(ir["id"])], uses: args_syms))

                when "select"
                  inline_needed_before!(ops, ir.fetch("args"), d, ctx:, view:, consts:, deps:, producer_cache:, axis_steps:)
                  args_syms = uses_for_args(ir["args"], consts, deps, ctx: ctx)
                  a, b, c = ir["args"].map { |a| ref(a, consts, deps, ctx: ctx) }
                  push!(ops, emit(code: "v#{ir['id']} = (#{a} ? #{b} : #{c})", depth: d, defines: [v(ir["id"])], uses: args_syms))

                when "loaddeclaration"
                  if deps[:inline_ids].include?(ir["id"]) && (dec = ctx[:inline]["op_#{ir['id']}"]) && dec["decision"] == "inline"
                    next
                  else
                    info = deps[:indexed].fetch(ir["id"]) # {name:, rank:}
                    idxs = (0...info[:rank]).map { |k| "[i#{k}]" }.join
                    push!(ops, emit(code: "v#{ir['id']} = self[:#{info[:name]}]#{idxs}", depth: d, defines: [v(ir["id"])], uses: []))
                  end

                when "constructtuple"
                  args_syms = uses_for_args(ir["args"], consts, deps, ctx: ctx)
                  push!(ops, emit(code: "v#{ir['id']} = [#{ir['args'].map { |a| ref(a, consts, deps, ctx: ctx) }.join(', ')}]",
                                  depth: d, defines: [v(ir["id"])], uses: args_syms))

                when "reduce"
                  rp = rps[ir["id"]] or next
                  red_id = key[rp, :op_id]
                  val_id = key[rp, :arg_id]
                  fn     = key[rp, :reducer_fn]

                  add_d   = clamp_pos.call(key[rp, :contrib_depth])
                  raw_bind_d = key[rp, :bind_depth]
                  bind_d = raw_bind_d.negative? ? raw_bind_d : clamp_pos.call(raw_bind_d)

                  # If contribution site is shallower than producer site, emit in :post (after inner closes)
                  val_site = clamp_pos.call(depth_of.fetch(val_id))
                  add_phase = (add_d < val_site) ? :post : :body

                  # Apply reducer: acc = reducer(acc, value)
                  push!(ops, acc_apply(name: acc(red_id), fn: fn, expr: v(val_id), depth: add_d, phase: add_phase))

                  # Bind result variable to accumulator at planned depth
                  push!(ops, emit(code: "v#{red_id} = #{acc(red_id)}",
                                  depth: bind_d, phase: :post,
                                  defines: [v(red_id)], uses: [acc(red_id)],
                                  op_type: :acc_bind))
                end
              end
            end

            # 5) Yield (scalars after all loops; arrays at their site)
            rid = ctx[:result_id]
            y_d = if (rp = rps[rid] || rps[rid.to_s])
                      # If result is from a reduce op, its true location is the bind_depth.
                      # The site_schedule can be stale.
                      raw_bind_d = key[rp, :bind_depth]
                      raw_bind_d.negative? ? raw_bind_d : clamp_pos.call(raw_bind_d)
                    else
                      ctx[:axes].empty? ? -1 : clamp_pos.call(depth_of.fetch(rid))
                    end
              
            indices = (0...rank).map { |k| "i#{k}" }
            y = CGIR::Op.yield(expr: v(rid), indices:, depth: y_d, phase: :post)
            y[:uses]    = Set[v(rid)]
            y[:defines] = Set.new
            push!(ops, y)

            # 6) Close loops deep → shallow
            axis_steps.length.times.reverse_each { |d| push!(ops, CGIR::Op.close_loop(depth: d, phase: :post)) }

            # 7) Topo order
            ops = TopoOrder.order(ops)
            CGIR::Function.new(name: ctx[:name], rank:, ops: ops)
          end

          # ---- helpers ----

          def emit(code:, depth:, defines:, uses:, phase: :body, op_type: nil)
            op = CGIR::Op.emit(code: code, depth: depth, phase: phase)
            op[:defines] = defines.to_set
            op[:uses]    = uses.to_set
            op[:op_type] = op_type if op_type
            op
          end

          # Apply reducer via kernel (ensures generated code calls e.g. "agg.sum")
          def acc_apply(name:, fn:, expr:, depth:, phase: :body)
            code = "#{name} = __call_kernel__(#{fn.inspect}, #{name}, #{expr})"
            op = CGIR::Op.emit(code: code, depth: depth, phase: phase)
            op[:defines] = Set[name]
            op[:uses]    = Set[name, expr]
            op[:op_type] = :acc_apply
            op
          end

          def v(id)   = "v#{id}"
          def c(id)   = "c#{id}"
          def acc(id) = "acc_#{id}"

          def uses_for_args(args, consts, deps, ctx: nil)
            args.filter_map { |a| a.is_a?(Integer) ? ref(a, consts, deps, ctx: ctx) : nil }
          end

          def const_preludes(consts, site_schedule)
            id_to_depth = {}
            site_schedule["by_depth"].each do |di|
              d = di["depth"]
              di["ops"].each { |o| id_to_depth[o["id"]] = d if o["kind"] == "const" }
            end
            seen = Set.new
            consts[:prelude].filter_map do |c|
              id = c[:name].delete_prefix("c").to_i
              next unless seen.add?(id)
              ["#{c[:name]} = #{literal(c[:value])}", id_to_depth.fetch(id, 0), id]
            end
          end

          def literal(x) = x.is_a?(String) ? x.inspect : x

          def ref(arg, consts, deps, ctx: nil)
            if arg.is_a?(Integer)
              if (producer_name = deps[:inline_scope]&.last)
                if (var = deps[:inline_map]&.dig(producer_name, arg))
                  return var
                end
              end
              if (var = deps[:rebind]&.[](arg))
                return var
              end
              const_name = "c#{arg}"
              return const_name if consts[:prelude].any? { |c| c[:name] == const_name }
              return "v#{arg}"
            end
            arg
          end

          # Build Ruby read expr relative to opened loops
          def input_expr_for_path(view, path_array, opened_loops_count)
            spec = view.input_spec_for_path(path_array)
            all_loops = Array(spec["axis_loops"])

            base = opened_loops_count.zero? ? "@input" : "a#{opened_loops_count - 1}"

            unopened = all_loops[opened_loops_count..-1] || []
            unopened.each do |loop_step|
              if loop_step["kind"] == "array_field"
                base = "#{base}[#{loop_step["key"].inspect}]"
              end
            end

            Array(spec["leaf_nav"]).reduce(base) do |acc, step|
              (step["kind"] || step[:kind]) == "field_leaf" ? "#{acc}[#{(step['key'] || step[:key]).inspect}]" : acc
            end
          end

          # Inlining helpers
          def inline_producer_operations(ops, load_decl_id:, producer_name:, producer_info:, consumer_depth:, view:, consts:, deps:, axis_steps:)
            key = producer_name
            deps[:inlined_producers] ||= {}
            return if deps[:inlined_producers][key]

            deps[:inline_scope] ||= []
            deps[:inline_map]   ||= {}
            deps[:rebind]       ||= {}

            deps[:inline_scope].push(producer_name)
            deps[:inline_map][producer_name] ||= {}

            pctx = producer_info[:ctx]
            result = pctx[:result_id]
            emitted_pconst = Set.new

            pctx[:site_schedule]["by_depth"].each do |dinfo|
              dinfo["ops"].each do |sched|
                pop = pctx[:ops].find { |o| o["id"] == sched["id"] }
                case sched["kind"]
                when "const"
                  next unless emitted_pconst.add?(pop["id"])
                  producer_value = pop['args'].first
                  existing_const = consts[:prelude].find { |c| c[:value] == producer_value }
                  var = existing_const ? existing_const[:name] : "c#{producer_name}_#{pop['id']}"
                  unless existing_const
                    push!(ops, emit(code: "#{var} = #{literal(producer_value)}", depth: consumer_depth, defines: [var], uses: []))
                  end
                  deps[:inline_map][producer_name][pop["id"]] = var

                when "loadinput"
                  expr = input_expr_for_path(view, pop["args"].first, axis_steps.length)
                  var  = pop["id"] == result ? v(load_decl_id) : "v#{pop['id']}_#{producer_name}"
                  push!(ops, emit(code: "#{var} = #{expr}", depth: consumer_depth, defines: [var], uses: []))
                  deps[:inline_map][producer_name][pop["id"]] = var

                when "map"
                  args_syms = pop["args"].filter_map { |a| a.is_a?(Integer) ? ref(a, consts, deps, ctx: pctx) : nil }
                  var = pop["id"] == result ? v(load_decl_id) : "v#{pop['id']}_#{producer_name}"
                  fn = pop["attrs"]["fn"]
                  push!(ops, emit(code: "#{var} = __call_kernel__(#{fn.inspect}, #{pop['args'].map { |a| ref(a, consts, deps, ctx: pctx) }.join(', ')})",
                                  depth: consumer_depth, defines: [var], uses: args_syms))
                  deps[:inline_map][producer_name][pop["id"]] = var
                  deps[:rebind][load_decl_id] = var if pop["id"] == result

                when "select"
                  a, b, c = pop["args"].map { |arg_id| ref(arg_id, consts, deps, ctx: pctx) }
                  var = pop["id"] == result ? v(load_decl_id) : "v#{pop['id']}_#{producer_name}"
                  args_syms = pop["args"].filter_map { |arg_id| arg_id.is_a?(Integer) ? ref(arg_id, consts, deps, ctx: pctx) : nil }
                  push!(ops, emit(code: "#{var} = (#{a} ? #{b} : #{c})", depth: consumer_depth, defines: [var], uses: args_syms))
                  deps[:inline_map][producer_name][pop["id"]] = var
                  deps[:rebind][load_decl_id] = var if pop["id"] == result
                end
              end
            end

            deps[:inline_scope].pop
            deps[:inlined_producers][key] = true
          end

          def inline_needed_before!(ops, arg_ids, consumer_depth, ctx:, view:, consts:, deps:, producer_cache:, axis_steps:)
            arg_ids.each do |aid|
              next unless aid.is_a?(Integer)
              ir = ctx[:ops].find { |o| o["id"] == aid } or next
              next unless ir["op"] == "LoadDeclaration"
              dec = ctx[:inline]["op_#{aid}"] or next
              next unless dec["decision"] == "inline"

              k = [aid, consumer_depth]
              deps[:inlined_once] ||= {}
              next if deps[:inlined_once][k]

              info = producer_cache.fetch(ir["args"].first.to_s)
              inline_producer_operations(ops, load_decl_id: aid, producer_name: ir["args"].first.to_s,
                                         producer_info: info, consumer_depth:, view:, consts:, deps:, axis_steps:)
              deps[:inlined_once][k] = true
            end
          end

          def push!(ops, op)
            op[:within_depth_sched] ||= ops.length
            ops << op
          end
        end
      end
    end
  end
end
