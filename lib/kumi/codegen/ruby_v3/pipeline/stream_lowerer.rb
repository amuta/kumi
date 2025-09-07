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
            axis_steps = view.navigation_steps_for_decl(ctx[:name], producer_cache: producer_cache)
            physical_max = [axis_steps.length - 1, 0].max
            clamp_pos    = ->(d) { [[d, 0].max, physical_max].min }

            depth_of = {}
            ctx[:site_schedule].fetch("by_depth").each do |dinfo|
              d = dinfo.fetch("depth")
              dinfo.fetch("ops").each { |o| depth_of[o.fetch("id")] = d }
            end

            rps = ctx[:reduce_plans_by_id] || {}
            key = ->(h, k) { h[k] || h[k.to_s] }

            # 1. Open loops by iterating directly over the planned axis_steps.
            axis_steps.each do |st|
              push!(ops, CGIR::Op.open_loop(
                depth: st["loop_idx"], step_kind: st["kind"], key: (st["kind"] == "array_field" ? st["key"] : nil)
              ))
            end

            # 2. Emit accumulator resets.
            rps.each_value do |rp|
              red_id  = key[rp, :op_id]
              init    = identities.fetch(key[rp, :reducer_fn])
              reset_d = key[rp, :reset_depth]
              push!(ops, emit(code: "#{acc(red_id)} = #{literal(init)}",
                              depth: reset_d, phase: :pre,
                              defines: [acc(red_id)], uses: []))
            end

            hoisted_all_ids = Set.new((ctx[:site_schedule]["hoisted_scalars"] || []).map { |s| s["id"] })

            # 3. Emit all scheduled operations.
            ctx[:site_schedule].fetch("by_depth").each do |dinfo|
              logical_d = dinfo.fetch("depth")
              dinfo.fetch("ops").each do |sched|
                ir = ctx[:ops].find { |o| o["id"] == sched["id"] }
                d  = hoisted_all_ids.include?(ir["id"]) ? -1 : clamp_pos.call(logical_d)

                case sched["kind"]
                when "loadinput"
                  expr = input_expr_for_path(view, ir.fetch("args").first, axis_steps.length)
                  push!(ops, emit(code: "#{op_var(ir['id'])} = #{expr}", depth: d, defines: [op_var(ir["id"])], uses: []))
                when "const"
                  # Only emit a variable for a Const if it's the final result.
                  next unless ir["id"] == ctx[:result_id]
                  push!(ops, emit(code: "#{op_var(ir['id'])} = #{literal(ir.fetch('args').first)}", depth: d, defines: [op_var(ir["id"])], uses: []))
                when "map"
                  args_exprs = ir["args"].map { |a| ref(a, ctx) }
                  push!(ops, emit(code: "#{op_var(ir['id'])} = __call_kernel__(#{ir.fetch('attrs').fetch('fn').inspect}, #{args_exprs.join(', ')})",
                                  depth: d, defines: [op_var(ir["id"])], uses: uses_for_args(ir["args"], ctx)))
                when "select"
                  a, b, c = ir["args"].map { |a| ref(a, ctx) }
                  push!(ops, emit(code: "#{op_var(ir['id'])} = (#{a} ? #{b} : #{c})", depth: d, defines: [op_var(ir["id"])], uses: uses_for_args(ir["args"], ctx)))
                when "loaddeclaration"
                  is_reduce_arg = rps.values.any? { |rp| key[rp, :arg_id] == ir["id"] }
                  next if is_reduce_arg # Skip; will be handled manually by the 'reduce' case.
                  info = deps.fetch(:indexed).fetch(ir["id"])
                  idxs = (0...info[:rank]).map { |k| "[i#{k}]" }.join
                  push!(ops, emit(code: "#{op_var(ir['id'])} = self[:#{info[:name]}]#{idxs}", depth: d, defines: [op_var(ir["id"])], uses: []))
                when "constructtuple"
                  args_exprs = ir["args"].map { |a| ref(a, ctx) }
                  push!(ops, emit(code: "#{op_var(ir['id'])} = [#{args_exprs.join(', ')}]",
                                  depth: d, defines: [op_var(ir["id"])], uses: uses_for_args(ir["args"], ctx)))
                when "reduce"
                  rp = rps[ir["id"]] or next
                  red_id = key[rp, :op_id]
                  val_id = key[rp, :arg_id]
                  fn     = key[rp, :reducer_fn]
                  add_d   = clamp_pos.call(key[rp, :contrib_depth])
                  raw_bind_d = key[rp, :bind_depth]
                  bind_d = raw_bind_d.negative? ? raw_bind_d : clamp_pos.call(raw_bind_d)
                  
                  # Manually emit the LoadDeclaration for the reduction's argument at the correct contribution depth.
                  arg_ir = ctx[:ops].find { |o| o["id"] == val_id }
                  info = deps.fetch(:indexed).fetch(val_id)
                  idxs = (0...info[:rank]).map { |k| "[i#{k}]" }.join
                  push!(ops, emit(code: "#{op_var(val_id)} = self[:#{info[:name]}]#{idxs}", depth: add_d, defines: [op_var(val_id)], uses: []))
                  
                  push!(ops, acc_apply(name: acc(red_id), fn: fn, expr: op_var(val_id), depth: add_d, phase: :body))
                  push!(ops, emit(code: "#{op_var(red_id)} = #{acc(red_id)}",
                                  depth: bind_d, phase: :post, defines: [op_var(red_id)], uses: [acc(red_id)], op_type: :acc_bind))
                end
              end
            end

            # 4. Yield the final result.
            rid = ctx[:result_id]
            yield_expr = op_var(rid)
            y_d = if (rp = rps[rid] || rps[rid.to_s])
                    raw_bind_d = key[rp, :bind_depth]
                    raw_bind_d.negative? ? raw_bind_d : clamp_pos.call(raw_bind_d)
                  else
                    ctx[:axes].empty? ? -1 : clamp_pos.call(depth_of.fetch(rid))
                  end
            indices = (0...rank).map { |k| "i#{k}" }
            y = CGIR::Op.yield(expr: yield_expr, indices:, depth: y_d, phase: :post)
            y[:uses]    = Set[yield_expr]
            y[:defines] = Set.new
            push!(ops, y)

            # 5. Close loops.
            axis_steps.length.times.reverse_each { |d| push!(ops, CGIR::Op.close_loop(depth: d, phase: :post)) }

            # 6. Topologically sort the final operation list.
            ops = TopoOrder.order(ops)
            CGIR::Function.new(name: ctx[:name], rank:, ops: ops)
          end

          def push!(ops, op)
            op[:within_depth_sched] ||= ops.length
            ops << op
          end

          def op_var(id) = "op#{id}"
          def acc(id) = "acc_#{id}"
          def literal(x) = x.is_a?(String) ? x.inspect : x

          def emit(code:, depth:, defines:, uses:, phase: :body, op_type: nil)
            op = CGIR::Op.emit(code: code, depth: depth, phase: phase)
            op[:defines] = defines.to_set
            op[:uses]    = uses.to_set
            op[:op_type] = op_type if op_type
            op
          end

          def acc_apply(name:, fn:, expr:, depth:, phase: :body)
            code = "#{name} = __call_kernel__(#{fn.inspect}, #{name}, #{expr})"
            op = CGIR::Op.emit(code: code, depth: depth, phase: phase)
            op[:defines] = Set[name]
            op[:uses]    = Set[name, expr]
            op[:op_type] = :acc_apply
            op
          end

          def uses_for_args(args, ctx)
            args.filter_map do |arg_id|
              next unless arg_id.is_a?(Integer)
              op = ctx[:ops].find { |o| o["id"] == arg_id }
              next if op && op["op"] == "Const"
              op_var(arg_id)
            end
          end

          def ref(arg, ctx)
            if arg.is_a?(Integer)
              op = ctx[:ops].find { |o| o["id"] == arg }
              if op && op["op"] == "Const"
                return literal(op["args"].first)
              end
              op_var(arg)
            else
              arg
            end
          end

          def input_expr_for_path(view, path_array, opened_loops_count)
            spec = view.input_spec_for_path(path_array)
            data_depth = spec["axes"].length
            base = if data_depth < opened_loops_count && opened_loops_count > 0
                     data_depth.zero? ? "@input" : "a#{data_depth - 1}"
                   else
                     opened_loops_count.zero? ? "@input" : "a#{opened_loops_count - 1}"
                   end
            Array(spec["leaf_nav"]).reduce(base) do |acc, step| # OUTDATED
              "#{acc}[#{(step['key']).inspect}]"
            end
          end
        end
      end
    end
  end
end