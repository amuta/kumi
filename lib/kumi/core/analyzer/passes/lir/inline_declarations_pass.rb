# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        module LIR
          class InlineDeclarationsPass < PassBase
            LIR        = Kumi::Core::LIR
            MAX_PASSES = 30

            def run(_errors)
              current_ops = get_state(:lir_module)
              @ids        = get_state(:id_generator)

              MAX_PASSES.times do
                new_ops, changed = run_one_pass(current_ops)
                unless changed
                  new_ops.freeze
                  return state.with(:lir_module, new_ops)
                              .with(:lir_02_inlined_ops_by_decl, new_ops)
                end
                current_ops = new_ops
              end
              raise "LIR inlining did not converge after #{MAX_PASSES} passes."
            end

            private

            def run_one_pass(ops_by_decl)
              @ops_by_decl = ops_by_decl
              @gamma       = detect_all_gammas(@ops_by_decl)
              changed = false
              fused = {}
              @ops_by_decl.each do |name, payload|
                original_ops = Array(payload[:operations])
                inlined_ops  = inline_top_level_decl(original_ops)
                fused[name]  = { operations: inlined_ops }
                changed ||= (inlined_ops != original_ops)
              end
              [fused, changed]
            end

            # ---------------- core ----------------

            Hoist = Struct.new(:ops, :target_depth, keyword_init: true)

            def inline_top_level_decl(ops)
              env        = Env.new
              reg_map    = {}
              rename_map = {}
              processed, hoist_pkgs = process_and_hoist_block(ops, env, reg_map, rename_map)

              top_emit, bubble = hoist_pkgs.partition { |p| p.target_depth == 0 }
              raise "Orphaned code hoist with target depth(s): #{bubble.map(&:target_depth).uniq.inspect}" unless bubble.empty?

              top_emit.flat_map(&:ops) + processed
            end

            # returns [processed_ops, hoist_pkgs]
            def process_and_hoist_block(block_ops, env, reg_map, rename_map)
              out = []
              hoisted_pkgs = []
              i = 0
              while i < block_ops.length
                ins = block_ops[i]
                case ins.opcode
                when :LoopStart
                  end_idx   = find_matching_loop_end(block_ops, i)
                  loop_body = block_ops[(i + 1)...end_idx]

                  env.push(ins)
                  child_rename = {}
                  processed_body, child_hoists =
                    process_and_hoist_block(loop_body, env, reg_map, child_rename)
                  env.pop

                  # Emit any hoists that belong exactly here; bubble the rest up.
                  depth_here = env.axes.length
                  emit, bubble = child_hoists.partition { |p| p.target_depth == depth_here }
                  out.concat(emit.flat_map(&:ops))
                  hoisted_pkgs.concat(bubble)

                  # guard: do not let child loop el/idx escape via rename
                  child_el = ins.attributes[:as_element]
                  child_ix = ins.attributes[:as_index]
                  if (child_rename.values & [child_el, child_ix]).any?
                    raise "rename leak across loop: #{[child_el, child_ix].inspect} via #{child_rename.inspect}"
                  end

                  # Merge renames *before* we emit the body, so all uses are rewritten.
                  rename_map.merge!(child_rename)

                  # Emit loop shell and rewritten body/end with the merged rename map.
                  out << rewrite(ins, reg_map, rename_map) # loop shell
                  out.concat(rewrite_block(processed_body, rename_map))
                  out << rewrite(block_ops[end_idx], reg_map, rename_map)

                  i = end_idx

                when :LoadDeclaration
                  inline_ops, new_pkgs =
                    handle_load_declaration(ins, env, reg_map, rename_map)
                  out.concat(inline_ops)
                  hoisted_pkgs.concat(new_pkgs)

                else
                  out << rewrite(ins, reg_map, rename_map)
                end
                i += 1
              end
              [out, hoisted_pkgs]
            end

            # returns [inline_ops, hoist_pkgs]
            def handle_load_declaration(ins, env, _reg_map, rename_map)
              callee = ins.immediates.first.value.to_sym

              # axes presence and agreement with callee gamma
              decl_axes  = ins.attributes.fetch(:axes) { raise "LoadDeclaration missing :axes for #{callee}" }
              gamma_axes = @gamma.fetch(callee).axes
              raise "axes mismatch for #{callee}: decl=#{decl_axes.inspect} gamma=#{gamma_axes.inspect}" unless decl_axes == gamma_axes

              body, yield_reg, callee_regs = inline_callee_core(callee)
              remap = remap_axes(callee_regs, env)

              # per-callsite freshening
              local_reg_map = {}
              _acc, fresh_ops = freshen(body, local_reg_map, pre_map: remap)

              # recursively process nested calls
              processed_inline, nested_pkgs = process_and_hoist_block(fresh_ops, env, {}, rename_map)

              # compute yielded register mapping
              mapped_yield =
                local_reg_map[yield_reg] || remap[yield_reg] ||
                (raise "inliner: yielded reg #{yield_reg} not produced in inlined body for #{callee}")

              # sanity: mapped_yield must be definable at site
              emitted_defs = processed_inline.map(&:result_register).compact +
                             nested_pkgs.flat_map { |p| p.ops }.map(&:result_register).compact
              unless emitted_defs.include?(mapped_yield) || env.ambient_regs.include?(mapped_yield)
                raise "inliner: mapped yield #{mapped_yield} has no def in emitted ops for #{callee}\n" \
                      "original yield: #{yield_reg}\n" \
                      "inline defs size: #{processed_inline.count { |x| x.result_register }}\n" \
                      "nested hoist defs size: #{nested_pkgs.flat_map { |p| p.ops }.count { |x| x.result_register }}"
              end

              # record rename for the callsite result (e.g., %t8 -> %t56)
              rename_map[ins.result_register] = mapped_yield

              # decide placement by depth
              site_depth   = env.axes.length
              callee_depth = decl_axes.length

              if callee_depth < site_depth
                # guard: hoisted code must not reference deeper-axis regs (check only code we hoist now)
                forb = forbidden_ambient_after(callee_depth, env)
                used = uses_of(processed_inline)
                bad  = used & forb
                unless bad.empty?
                  raise "scope error: would hoist ops using deeper-axis regs #{bad.inspect} " \
                        "(callee_depth=#{callee_depth}, site_depth=#{site_depth})"
                end
                pkgs = nested_pkgs + [Hoist.new(ops: processed_inline, target_depth: callee_depth)]
                [[], pkgs]

              elsif callee_depth == site_depth
                emit, bubble = nested_pkgs.partition { |p| p.target_depth == site_depth }
                [(emit.flat_map(&:ops) + processed_inline), bubble]

              else
                # cannot inline at a shallower site; keep the call
                [[rewrite(ins, {}, rename_map)], []]
              end
            end

            # ---------------- helpers ----------------
            def rewrite_block(ops, rename)
              # Ensure late-added renames apply to a block we built earlier.
              ops.map { |ins| rewrite(ins, {}, rename) }
            end

            def uses_of(ops)
              ops.flat_map { |x| Array(x.inputs) }.compact
            end

            def forbidden_ambient_after(depth, env)
              env.frames_after(depth).flat_map { |f| [f[:el], f[:idx]] }
            end

            def find_matching_loop_end(ops, start_index)
              depth = 1
              (start_index + 1...ops.length).each do |i|
                op = ops[i].opcode
                depth += 1 if op == :LoopStart
                depth -= 1 if op == :LoopEnd
                return i if depth.zero?
              end
              raise "Unbalanced LoopStart at index #{start_index}"
            end

            def remap_axes(callee_axis_regs, env)
              callee_axis_regs.each_with_object({}) do |r, h|
                caller = env.reg_for_axis(r[:axis])
                h[r[:el]]  = caller[:el]
                h[r[:idx]] = caller[:idx]
              end
            end

            class Env
              def initialize = @frames = []
              def axes = @frames.map { _1[:axis] }
              def ambient_regs = @frames.flat_map { |f| [f[:el], f[:idx]] }

              def push(loop_ins)
                @frames << {
                  axis: loop_ins.attributes[:axis],
                  el: loop_ins.attributes[:as_element],
                  idx: loop_ins.attributes[:as_index]
                }
              end

              def pop = @frames.pop

              def reg_for_axis(axis)
                @frames.reverse.find { _1[:axis] == axis } ||
                  raise("no element for axis=#{axis.inspect}")
              end

              def frames_after(depth)
                @frames[depth..] || []
              end
            end

            def detect_all_gammas(ops_by_decl)
              ops_by_decl.transform_values { |p| detect_gamma(Array(p[:operations])) }
            end

            GammaInfo = Struct.new(:start_idx, :axes, :axis_regs, keyword_init: true)

            def detect_gamma(ops)
              frames = []
              ops.each do |ins|
                case ins.opcode
                when :LoopStart
                  frames << {
                    axis: ins.attributes[:axis],
                    el: ins.attributes[:as_element],
                    idx: ins.attributes[:as_index]
                  }
                when :LoopEnd
                  frames.pop
                when :Yield
                  axes = frames.map { _1[:axis] }
                  axis_regs = frames.map { |f| { axis: f[:axis], el: f[:el], idx: f[:idx] } }
                  return GammaInfo.new(start_idx: nil, axes: axes, axis_regs: axis_regs)
                end
              end
              GammaInfo.new(start_idx: nil, axes: [], axis_regs: [])
            end

            def inline_callee_core(callee_name)
              ops  = Array(@ops_by_decl.fetch(callee_name)[:operations])
              info = @gamma.fetch(callee_name)
              axes = info.axes
              k    = axes.length

              yi = ops.rindex { |x| x.opcode == :Yield } or raise "callee #{callee_name} has no Yield"
              yielded_reg = Array(ops[yi].inputs).first

              first_loop = ops.index { |x| x.opcode == :LoopStart }
              return [ops[0...yi], yielded_reg, info.axis_regs] unless first_loop

              prologue   = ops[0...first_loop]
              main       = ops[first_loop...yi]
              inner_body = []
              open_gamma = 0
              stack = []
              main.each do |ins|
                case ins.opcode
                when :LoopStart
                  if open_gamma < k && ins.attributes[:axis] == axes[open_gamma]
                    stack << :gamma
                    open_gamma += 1
                  else
                    stack << :inner
                    inner_body << ins
                  end
                when :LoopEnd
                  inner_body << ins if stack.pop == :inner
                else
                  inner_body << ins
                end
              end
              [prologue + inner_body, yielded_reg, info.axis_regs]
            end

            def freshen(block_ops, reg_map, pre_map: {})
              acc_map = {}
              new_ops = block_ops.map do |ins|
                attrs = (ins.attributes || {}).dup

                if ins.opcode == :LoopStart
                  attrs[:id] = @ids.generate_loop_id
                  new_el  = @ids.generate_temp
                  new_idx = @ids.generate_temp
                  reg_map[attrs[:as_element]] = new_el
                  reg_map[attrs[:as_index]]   = new_idx
                  attrs[:as_element] = new_el
                  attrs[:as_index]   = new_idx
                end

                res = ins.result_register
                reg_map[res] ||= @ids.generate_temp if res

                new_inputs = Array(ins.inputs).map do |r|
                  r1 = pre_map.fetch(r, r)
                  reg_map.fetch(r1, r1)
                end

                case ins.opcode
                when :DeclareAccumulator
                  orig = ins.result_register
                  acc_map[orig] ||= @ids.generate_acc
                  res = acc_map[orig]
                when :Accumulate
                  orig = ins.result_register
                  acc_map[orig] ||= @ids.generate_acc
                  res = acc_map[orig]
                when :LoadAccumulator
                  orig = ins.inputs.first
                  acc_map[orig] ||= @ids.generate_acc
                  new_inputs[0] = acc_map[orig]
                end

                LIR::Instruction.new(
                  opcode: ins.opcode,
                  result_register: res ? reg_map.fetch(res, res) : nil,
                  stamp: ins.stamp,
                  inputs: new_inputs,
                  immediates: ins.immediates,
                  attributes: attrs,
                  location: ins.location
                )
              end
              [acc_map, new_ops]
            end

            def rewrite(ins, _reg_map, rename)
              new_inputs = Array(ins.inputs).map { |r| rename.fetch(r, r) }
              LIR::Instruction.new(
                opcode: ins.opcode,
                result_register: ins.result_register,
                stamp: ins.stamp,
                inputs: new_inputs,
                immediates: ins.immediates,
                attributes: ins.attributes,
                location: ins.location
              )
            end

            def prefix?(pre, full)
              pre.each_with_index.all? { |tok, i| full[i] == tok }
            end
          end
        end
      end
    end
  end
end
