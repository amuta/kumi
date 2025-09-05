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

            # Get axis loops aligned by declaration's computation axes + reduce axes
            axis_steps = view.axis_loops_for_decl(ctx[:name], producer_cache: producer_cache)

            # Clamp logical site depths to opened loop ceiling  
            physical_max = [axis_steps.length - 1, 0].max
            clamp = ->(d) { [[d, 0].max, physical_max].min }

            # map op id → (logical) scheduled depth
            depth_of = {}
            ctx[:site_schedule].fetch("by_depth").each do |dinfo|
              d = dinfo.fetch("depth")
              dinfo.fetch("ops").each { |o| depth_of[o.fetch("id")] = d }
            end

            # Open loops at their assigned depths
            axis_steps.each do |st|
              push!(ops, CGIR::Op.open_loop(
                depth: st["loop_idx"], step_kind: st["kind"], key: (st["kind"] == "array_field" ? st["key"] : nil)
              ))
            end

            # AccReset for reductions at result depth
            ctx[:reduce_plans].each do |rp|
              red_id = rp.fetch("op_id")
              init   = identities.fetch(rp.fetch("reducer_fn"))
              push!(ops, CGIR::Op.acc_reset(name: acc(red_id), depth: clamp.call(rp.fetch("result_depth")), init: init, phase: :pre))
            end

            # Prelude consts at scheduled depth (:pre)
            const_preludes(consts, ctx[:site_schedule]).each do |(code, d, cid)|
              push!(ops, emit(code: code, depth: clamp.call(d), phase: :pre, defines: [c(cid)], uses: [], op_type: :const_prelude))
            end

            hoisted_const_ids = Set.new((ctx[:site_schedule]["hoisted_scalars"] || []).select { |s| s["kind"] == "const" }.map { |s| s["id"] })
            hoisted_all_ids   = Set.new((ctx[:site_schedule]["hoisted_scalars"] || []).map { |s| s["id"] })

            # Scheduled ops
            ctx[:site_schedule].fetch("by_depth").each do |dinfo|
              logical_d = dinfo.fetch("depth")
              dinfo.fetch("ops").each do |sched|
                ir = ctx[:ops].find { |o| o["id"] == sched["id"] }
                d  = hoisted_all_ids.include?(ir["id"]) ? logical_d : clamp.call(logical_d)

                case sched["kind"]
                when "loadinput"
                  path = ir.fetch("args").first
                  expr = input_expr_for_path(view, path, axis_steps.length) 
                  push!(ops, emit(code: "v#{ir['id']} = #{expr}", depth: d, defines: [v(ir["id"])], uses: []))

                when "const"
                  next if consts[:inline_ids].include?(ir["id"]) || hoisted_const_ids.include?(ir["id"])
                  val = ir.fetch("args").first
                  push!(ops, emit(code: "c#{ir['id']} = #{literal(val)}", depth: d, defines: [c(ir["id"])], uses: []))

                when "map"
                  inline_needed_before!(ops, ir.fetch("args"), d, ctx:, view:, consts:, deps:, producer_cache:, axis_steps:)
                  args_syms = uses_for_args(ir["args"], consts, deps)
                  fn = ir.fetch("attrs").fetch("fn")
                  push!(ops, emit(code: "v#{ir['id']} = __call_kernel__(#{fn.inspect}, #{ir['args'].map { |a| ref(a, consts, deps) }.join(', ')})",
                                  depth: d, defines: [v(ir["id"])], uses: args_syms))

                when "select"
                  inline_needed_before!(ops, ir.fetch("args"), d, ctx:, view:, consts:, deps:, producer_cache:, axis_steps:)
                  args_syms = uses_for_args(ir["args"], consts, deps)
                  a, b, c = ir["args"].map { |a| ref(a, consts, deps) }
                  push!(ops, emit(code: "v#{ir['id']} = (#{a} ? #{b} : #{c})", depth: d, defines: [v(ir["id"])], uses: args_syms))

                when "loaddeclaration"
                  if deps[:inline_ids].include?(ir["id"]) && (dec = ctx[:inline]["op_#{ir['id']}"]) && dec["decision"] == "inline"
                    next # will inline at consumer sites
                  else
                    info = deps[:indexed].fetch(ir["id"]) # {name:, rank:}
                    idxs = (0...info[:rank]).map { |k| "[i#{k}]" }.join
                    push!(ops, emit(code: "v#{ir['id']} = self[:#{info[:name]}]#{idxs}", depth: d, defines: [v(ir["id"])], uses: []))
                  end

                when "constructtuple"
                  args_syms = uses_for_args(ir["args"], consts, deps)
                  push!(ops, emit(code: "v#{ir['id']} = [#{ir['args'].map { |a| ref(a, consts, deps) }.join(', ')}]",
                                  depth: d, defines: [v(ir["id"])], uses: args_syms))

                when "reduce"
                  rp = ctx[:reduce_plans].find { |r| r["op_id"] == ir["id"] }
                  next unless rp

                  val_id = rp.fetch("arg_id"); red_id = rp.fetch("op_id"); result_depth = rp.fetch("result_depth")
                  input_is_reduction = ctx[:reduce_plans].any? { |r| r["op_id"] == val_id }

                  if input_is_reduction
                    child_rp = ctx[:reduce_plans].find { |r| r["op_id"] == val_id }
                    push!(ops, acc_add(name: acc(red_id), expr: v(val_id), depth: clamp.call(child_rp.fetch("result_depth")), phase: :post))
                  else
                    input_depth = clamp.call(depth_of.fetch(val_id))
                    push!(ops, acc_add(name: acc(red_id), expr: v(val_id), depth: input_depth, phase: :body))
                  end

                  push!(ops, emit(code: "v#{red_id} = #{acc(red_id)}", depth: clamp.call(result_depth), phase: :post,
                                  defines: [v(red_id)], uses: [acc(red_id)], op_type: :result_processing))
                end
              end
            end

            # Yield at clamped result depth
            rid = ctx[:result_id]
            y_d = clamp.call(depth_of.fetch(rid))
            indices = (0...rank).map { |k| "i#{k}" }
            y = CGIR::Op.yield(expr: v(rid), indices:, depth: y_d, phase: :post)
            y[:uses] = Set[v(rid)]
            y[:defines] = Set.new
            push!(ops, y)

            # Close loops (deep → shallow)
            axis_steps.length.times.reverse_each { |d| push!(ops, CGIR::Op.close_loop(depth: d, phase: :post)) }

            # Final topo order
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

          def acc_add(name:, expr:, depth:, phase: :body)
            op = CGIR::Op.acc_add(name: name, expr: expr, depth: depth, phase: phase)
            op[:defines] = Set[name]
            op[:uses]    = Set[name, expr]
            op
          end

          def v(id)   = "v#{id}"
          def c(id)   = "c#{id}"
          def acc(id) = "acc_#{id}"

          def uses_for_args(args, consts, deps)
            args.filter_map do |a|
              next unless a.is_a?(Integer)
              if deps[:inlined_vars]&.key?(a)
                deps[:inlined_vars][a]
              elsif consts[:prelude].any? { |c| c[:name] == "c#{a}" }
                "c#{a}"
              else
                "v#{a}"
              end
            end
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

          def ref(arg, consts, deps)
            return "c#{arg}" if arg.is_a?(Integer) && consts[:prelude].any? { |c| c[:name] == "c#{arg}" }
            return deps[:inlined_vars][arg] if deps[:inlined_vars]&.key?(arg)
            arg.is_a?(Integer) ? "v#{arg}" : arg
          end

          # NEW: build Ruby read expr relative to opened loops (not input spec's total loops)
          def input_expr_for_path(view, path_array, opened_loops_count)
            spec = view.input_spec_for_path(path_array)
            all_loops = Array(spec["axis_loops"])
            
            # Start from @input or deepest opened loop variable
            if opened_loops_count.zero?
              base = "@input"
            else
              base = "a#{opened_loops_count - 1}"
            end
            
            # Navigate through any axis_loops we didn't open
            unopened_loops = all_loops[opened_loops_count..-1] || []
            unopened_loops.each do |loop_step|
              if loop_step["kind"] == "array_field"
                base = "#{base}[#{loop_step["key"].inspect}]"
              end
            end
            
            # Add leaf navigation  
            Array(spec["leaf_nav"]).reduce(base) do |acc, step|
              (step["kind"] || step[:kind]) == "field_leaf" ? "#{acc}[#{(step['key'] || step[:key]).inspect}]" : acc
            end
          end

          def inline_producer_operations(ops, load_decl_id:, producer_name:, producer_info:, consumer_depth:, view:, consts:, deps:, axis_steps:)
            key = producer_name
            deps[:inlined_producers] ||= {}
            return if deps[:inlined_producers][key]

            deps[:inlined_vars] ||= {}
            pctx = producer_info[:ctx]
            result = pctx[:result_id]
            emitted_pconst = Set.new

            pctx[:site_schedule]["by_depth"].each do |dinfo|
              dinfo["ops"].each do |sched|
                pop = pctx[:ops].find { |o| o["id"] == sched["id"] }
                case sched["kind"]
                when "const"
                  next unless emitted_pconst.add?(pop["id"])
                  var = "c#{producer_name}_#{pop['id']}"
                  deps[:inlined_vars][pop["id"]] = var
                  push!(ops, emit(code: "#{var} = #{literal(pop['args'].first)}", depth: consumer_depth, defines: [var], uses: []))

                when "loadinput"
                  # For inline producers, use the axis_steps to determine loops opened
                  expr = input_expr_for_path(view, pop["args"].first, axis_steps.length)
                  var  = pop["id"] == result ? v(load_decl_id) : "v#{pop['id']}_#{producer_name}"
                  deps[:inlined_vars][pop["id"]] = var
                  push!(ops, emit(code: "#{var} = #{expr}", depth: consumer_depth, defines: [var], uses: []))

                when "map"
                  args_syms = pop["args"].filter_map do |a|
                    if a.is_a?(Integer) && deps[:inlined_vars]&.key?(a)
                      deps[:inlined_vars][a]
                    elsif a.is_a?(Integer)
                      a == result ? v(load_decl_id) : "v#{a}_#{producer_name}"
                    end
                  end
                  var = pop["id"] == result ? v(load_decl_id) : "v#{pop['id']}_#{producer_name}"
                  deps[:inlined_vars][pop["id"]] = var
                  fn = pop["attrs"]["fn"]
                  push!(ops, emit(code: "#{var} = __call_kernel__(#{fn.inspect}, #{pop['args'].map { |a| ref(a, { prelude: [], inline_ids: Set.new }, deps) }.join(', ')})",
                                  depth: consumer_depth, defines: [var], uses: args_syms.compact))

                when "select"
                  a, b, c = pop["args"].map { |a| ref(a, { prelude: [], inline_ids: Set.new }, deps) }
                  var = pop["id"] == result ? v(load_decl_id) : "v#{pop['id']}_#{producer_name}"
                  deps[:inlined_vars][pop["id"]] = var
                  args_syms = pop["args"].filter_map { |a| a.is_a?(Integer) ? (deps[:inlined_vars][a] || (a == result ? v(load_decl_id) : "v#{a}_#{producer_name}")) : nil }
                  push!(ops, emit(code: "#{var} = (#{a} ? #{b} : #{c})", depth: consumer_depth, defines: [var], uses: args_syms))
                end
              end
            end

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