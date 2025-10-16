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

            def inline_top_level_decl(ops)
              env        = Env.new
              reg_map    = {}
              rename_map = {}
              processed, hoisted = process_and_hoist_block(ops, env, reg_map, rename_map)
              raise "Orphaned code was hoisted to top level" unless hoisted.empty?

              processed
            end

            # ---------------- core ----------------

            # returns [processed_ops, hoisted_ops]
            def process_and_hoist_block(block_ops, env, reg_map, rename_map)
              out = []
              hoisted = []
              i = 0
              while i < block_ops.length
                ins = block_ops[i]
                case ins.opcode
                when :LoopStart
                  end_idx   = find_matching_loop_end(block_ops, i)
                  loop_body = block_ops[(i + 1)...end_idx]

                  env.push(ins)
                  child_rename = {}
                  processed_body, hoisted_from_child =
                    process_and_hoist_block(loop_body, env, reg_map, child_rename)
                  env.pop

                  out.concat(hoisted_from_child)            # emit hoists before loop
                  rename_map.merge!(child_rename)           # make child renames visible

                  out << rewrite(ins, reg_map, rename_map)  # loop shell
                  out.concat(processed_body)
                  out << rewrite(block_ops[end_idx], reg_map, rename_map)

                  i = end_idx

                when :LoadDeclaration
                  inline_ops, hoist_ops =
                    handle_load_declaration(ins, env, reg_map, rename_map)
                  out.concat(inline_ops)
                  hoisted.concat(hoist_ops)

                else
                  out << rewrite(ins, reg_map, rename_map)
                end
                i += 1
              end
              [out, hoisted]
            end

            # returns [inline_ops, hoisted_ops]
            def handle_load_declaration(call_ins, env, reg_map, outer_rename_map)
              raise "LoadDeclaration missing callee" unless call_ins.immediates&.first&.respond_to?(:value)

              callee = call_ins.immediates.first.value.to_sym
              raise "LoadDeclaration callee #{callee} not found" unless @ops_by_decl.key?(callee)

              decl_axes = fetch_decl_axes(callee, call_ins)
              site_axes = env.axes

              body, yield_reg, callee_axis_regs = inline_callee_core(callee)
              axis_map = remap_axes(callee_axis_regs, env)

              local_reg_map = {}
              _acc, fresh_ops = freshen(body, local_reg_map, pre_map: axis_map)

              nested_rename = {}
              processed_inner, hoisted_inner =
                process_and_hoist_block(fresh_ops, env, {}, nested_rename)

              prelim = local_reg_map[yield_reg] || axis_map[yield_reg] || yield_reg
              mapped_yield = resolve_rename(prelim, nested_rename)

              # def/dominance guard
              defs_inline  = defs_in(processed_inner)
              defs_hoisted = defs_in(hoisted_inner)
              unless defs_inline.include?(mapped_yield) || defs_hoisted.include?(mapped_yield)
                msg = [
                  "inliner: mapped yield #{mapped_yield} has no def in emitted ops for #{callee}",
                  "  original yield: #{yield_reg}",
                  "  prelim mapping: #{prelim}",
                  "  nested_rename keys: #{nested_rename.keys.inspect}",
                  "  inline defs size: #{defs_inline.size}",
                  "  hoisted defs size: #{defs_hoisted.size}"
                ].join("\n")
                raise msg
              end

              outer_rename_map[call_ins.result_register] = mapped_yield if call_ins.result_register

              if prefix?(decl_axes, site_axes) && decl_axes.length < site_axes.length
                [[], hoisted_inner + processed_inner]         # hoist
              elsif decl_axes == site_axes
                [hoisted_inner + processed_inner, []]         # inline in place
              else
                [[rewrite(call_ins, reg_map, outer_rename_map)], []] # cannot inline
              end
            end

            # ---------------- helpers ----------------

            def resolve_rename(reg, rename, limit: 64)
              seen = {}
              cur = reg
              limit.times do
                nxt = rename[cur]
                break unless nxt
                raise "inliner: rename cycle at #{cur}" if seen[nxt]

                seen[nxt] = true
                cur = nxt
              end
              cur
            end

            def defs_in(ops)
              ops.each_with_object(Set.new) { |ins, s| s << ins.result_register if ins.result_register }
            end

            def fetch_decl_axes(callee, call_ins)
              attr_axes  = call_ins.attributes && call_ins.attributes[:axes]
              gamma_axes = Array(@gamma.fetch(callee)&.axes || [])
              ax = attr_axes.nil? ? gamma_axes : Array(attr_axes)
              raise "LoadDeclaration missing :axes" if ax.nil?
              raise "inliner: non-array axes for #{callee}: #{ax.inspect}" unless ax.is_a?(Array)

              ax
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
              ops = Array(@ops_by_decl.fetch(callee_name)[:operations])
              info = @gamma.fetch(callee_name)
              axes = info.axes
              k = axes.length

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
