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

            # AccReset at the parent of the INPUT contribution site (group boundary)
            ctx[:reduce_plans].each do |rp|
              red_id = rp.fetch("op_id")
              init   = identities.fetch(rp.fetch("reducer_fn"))
              arg_id = rp.fetch("arg_id")

              if (child = ctx[:reduce_plans].find { |r| r["op_id"] == arg_id })
                # NESTED: reset one level above THIS reduction's result group.
                # Allow -1 so outermost global reductions reset before any loop opens.
                result_d    = rp.fetch("result_depth")      # logical (not clamped)
                group_depth = result_d - 1                  # may be -1
              else
                # DIRECT: reset one level above the arg op's clamped site.
                arg_d       = clamp.call(depth_of.fetch(arg_id))
                group_depth = [arg_d - 1, 0].max
              end
              push!(ops, CGIR::Op.acc_reset(name: acc(red_id), depth: group_depth, init: init, phase: :pre))
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
                  # Namespace constants by declaration name to prevent collisions
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
                    next # will inline at consumer sites
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
                  rp = ctx[:reduce_plans].find { |r| r["op_id"] == ir["id"] }
                  next unless rp

                  val_id = rp.fetch("arg_id"); red_id = rp.fetch("op_id"); result_depth = rp.fetch("result_depth")
                  input_is_reduction = ctx[:reduce_plans].any? { |r| r["op_id"] == val_id }
                  consumed_by_parent = ctx[:reduce_plans].any? { |r| r["arg_id"] == red_id }  # NEW

                  if input_is_reduction
                    child_rp = ctx[:reduce_plans].find { |r| r["op_id"] == val_id }
                    parent_d = clamp.call(child_rp.fetch("result_depth") - 1)  # move up one level
                    push!(ops, acc_add(name: acc(red_id), expr: v(val_id), depth: parent_d, phase: :post))

                    bind_d = clamp.call(result_depth)
                  else
                    input_depth = clamp.call(depth_of.fetch(val_id))
                    push!(ops, acc_add(name: acc(red_id), expr: v(val_id), depth: input_depth, phase: :body))

                    # bind inner (direct) reductions at the group boundary only if a parent consumes them
                    bind_d = consumed_by_parent ? [input_depth - 1, 0].max : clamp.call(result_depth)
                  end

                  push!(ops, emit(code: "v#{red_id} = #{acc(red_id)}", depth: bind_d, phase: :post,
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

          def uses_for_args(args, consts, deps, ctx: nil)
            args.filter_map do |a|
              next unless a.is_a?(Integer)
              # Use the same logic as ref() function for consistency
              ref(a, consts, deps, ctx: ctx)
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

          def ref(arg, consts, deps, ctx: nil)
            if arg.is_a?(Integer)
              # 1) If inside producer inline, prefer producer-scoped mapping
              if (producer_name = deps[:inline_scope]&.last)
                if (var = deps[:inline_map]&.dig(producer_name, arg))
                  return var
                end
              end
              
              # 2) Consumer-level rebinds (e.g., LoadDeclaration -> inlined result)  
              if (var = deps[:rebind]&.[](arg))
                return var
              end
              
              # 3) Constants - check if constant exists in prelude
              const_name = "c#{arg}"
              if consts[:prelude].any? { |c| c[:name] == const_name }
                return const_name
              end
              
              # 4) Fallback to raw SSA var
              return "v#{arg}"
            end
            
            # Non-integer arguments pass through
            arg
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

            # Initialize scoped maps  
            deps[:inline_scope] ||= []
            deps[:inline_map]   ||= {}
            deps[:rebind]       ||= {}
            
            # Push producer scope
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
                  
                  # Try to find an existing constant with the same value
                  producer_value = pop['args'].first
                  existing_const = consts[:prelude].find { |c| c[:value] == producer_value }
                  
                  if existing_const
                    # Reuse existing constant with same value
                    var = existing_const[:name]
                  else
                    # Need to generate new producer-scoped constant  
                    var = "c#{producer_name}_#{pop['id']}"
                    push!(ops, emit(code: "#{var} = #{literal(producer_value)}", depth: consumer_depth, defines: [var], uses: []))
                  end
                  
                  # Record in producer-scoped mapping
                  deps[:inline_map][producer_name][pop["id"]] = var

                when "loadinput"
                  # For inline producers, use the axis_steps to determine loops opened
                  expr = input_expr_for_path(view, pop["args"].first, axis_steps.length)
                  var  = pop["id"] == result ? v(load_decl_id) : "v#{pop['id']}_#{producer_name}"
                  
                  # Emit the operation first
                  push!(ops, emit(code: "#{var} = #{expr}", depth: consumer_depth, defines: [var], uses: []))
                  
                  # Record in producer-scoped mapping
                  deps[:inline_map][producer_name][pop["id"]] = var

                when "map"
                  args_syms = pop["args"].filter_map do |a|
                    next unless a.is_a?(Integer)
                    # Use the new ref function which will resolve producer-scoped variables
                    ref(a, consts, deps, ctx: pctx)
                  end
                  var = pop["id"] == result ? v(load_decl_id) : "v#{pop['id']}_#{producer_name}"
                  
                  # Generate the map operation
                  fn = pop["attrs"]["fn"]
                  push!(ops, emit(code: "#{var} = __call_kernel__(#{fn.inspect}, #{pop['args'].map { |a| ref(a, consts, deps, ctx: pctx) }.join(', ')})",
                                  depth: consumer_depth, defines: [var], uses: args_syms.compact))
                  
                  # Record in producer-scoped mapping
                  deps[:inline_map][producer_name][pop["id"]] = var
                  
                  # If this is the result operation, rebind the consumer LoadDeclaration to this result variable
                  if pop["id"] == result
                    deps[:rebind][load_decl_id] = var
                  end

                when "select"
                  # Use the new ref function which will resolve producer-scoped variables
                  a, b, c = pop["args"].map { |arg_id| ref(arg_id, consts, deps, ctx: pctx) }
                  var = pop["id"] == result ? v(load_decl_id) : "v#{pop['id']}_#{producer_name}"
                  args_syms = pop["args"].filter_map do |arg_id|
                    next unless arg_id.is_a?(Integer)
                    ref(arg_id, consts, deps, ctx: pctx)
                  end
                  
                  # Emit the operation first
                  push!(ops, emit(code: "#{var} = (#{a} ? #{b} : #{c})", depth: consumer_depth, defines: [var], uses: args_syms.compact))
                  
                  # Record in producer-scoped mapping
                  deps[:inline_map][producer_name][pop["id"]] = var
                  
                  # If this is the result operation, rebind the consumer LoadDeclaration to this result variable
                  if pop["id"] == result
                    deps[:rebind][load_decl_id] = var
                  end
                end
              end
            end

            # Pop producer scope
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