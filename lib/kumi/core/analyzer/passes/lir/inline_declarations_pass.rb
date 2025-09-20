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
                  return state.with(:lir_module, new_ops).with(:lir_02_inlined_ops_by_decl, new_ops)
                end
                current_ops = new_ops
              end

              raise "LIR inlining did not converge after #{MAX_PASSES} passes."
            end

            private

            # --- UNCHANGED: Top-level pass logic ---
            def run_one_pass(ops_by_decl)
              @ops_by_decl = ops_by_decl
              @gamma       = detect_all_gammas(@ops_by_decl)
              changed = false
              fused = {}
              @ops_by_decl.each do |name, payload|
                original_ops = Array(payload[:operations])

                # Call the new top-level inliner
                inlined_ops = inline_top_level_decl(original_ops)

                fused[name] = { operations: inlined_ops }
                changed ||= (inlined_ops != original_ops)
              end
              [fused, changed]
            end

            # --- NEW: Top-level entry point for the recursive processor ---
            def inline_top_level_decl(ops)
              env = Env.new
              reg_map = {}
              rename_map = {}
              processed_ops, hoisted_ops = process_and_hoist_block(ops, env, reg_map, rename_map)

              # Hoisting is not allowed at the top level of a declaration
              raise "Orphaned code was hoisted to top level" unless hoisted_ops.empty?

              processed_ops
            end

            # --- NEW: The core recursive block processor ---
            # Returns two arrays: [ processed_instructions_for_this_block, instructions_to_hoist_up_one_level ]
            def process_and_hoist_block(block_ops, env, reg_map, rename_map)
              out_ops = []
              hoisted_out_ops = [] # Operations to be returned to the parent scope
              i = 0

              while i < block_ops.length
                ins = block_ops[i]
                case ins.opcode
                when :LoopStart
                  end_idx = find_matching_loop_end(block_ops, i)
                  loop_body = block_ops[(i + 1)...end_idx]

                  env.push(ins)
                  processed_body, hoisted_from_child = process_and_hoist_block(loop_body, env, reg_map, rename_map)
                  env.pop

                  # This is the crucial step: emit code hoisted from the child loop
                  # BEFORE emitting the child loop itself.
                  out_ops.concat(hoisted_from_child)

                  # Now, emit the reconstructed loop with its processed body
                  out_ops << rewrite(ins, reg_map, rename_map)
                  out_ops.concat(processed_body)
                  out_ops << rewrite(block_ops[end_idx], reg_map, rename_map)

                  i = end_idx # Jump iterator past the entire loop block

                when :LoadDeclaration
                  # This helper now decides if ops go inline or get returned for hoisting
                  inline_ops, hoist_ops = handle_load_declaration(ins, env, reg_map, rename_map)
                  out_ops.concat(inline_ops)
                  hoisted_out_ops.concat(hoist_ops)

                else
                  out_ops << rewrite(ins, reg_map, rename_map)
                end
                i += 1
              end

              [out_ops, hoisted_out_ops]
            end

            # --- NEW: Helper to manage LoadDeclaration logic ---
            # Returns two arrays: [ instructions_to_add_inline, instructions_to_hoist ]
            def handle_load_declaration(ins, env, reg_map, rename_map)
              callee = ins.immediates.first.value.to_sym
              decl_axes = ins.attributes.fetch(:axes)
              site_axes = env.axes

              body, yield_reg, callee_regs = inline_callee_core(callee)
              remap = remap_axes(callee_regs, env)
              _acc, fresh_ops = freshen(body, reg_map, pre_map: remap)

              rename_yielded_register(ins, yield_reg, reg_map, remap, rename_map)

              # Case 1: Hoisting
              if prefix?(decl_axes, site_axes) && decl_axes.length < site_axes.length
                [[], fresh_ops] # Return ops in the 'hoist' bucket
              # Case 2: In-place
              elsif decl_axes == site_axes
                [fresh_ops, []] # Return ops in the 'inline' bucket
              # Case 3: Cannot inline
              else
                [[rewrite(ins, reg_map, rename_map)], []]
              end
            end

            # --- UNCHANGED AND ORIGINAL HELPERS ---

            def find_matching_loop_end(ops, start_index)
              depth = 1; (start_index + 1...ops.length).each do |i|
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
                h[r[:el]] = caller[:el]
                h[r[:idx]] = caller[:idx]
              end
            end

            def rename_yielded_register(ins, yielded_reg, reg_map, axis_remap, rename)
              return unless ins.result_register && yielded_reg

              mapped = reg_map.fetch(yielded_reg, axis_remap.fetch(yielded_reg, yielded_reg))
              rename[ins.result_register] = mapped
            end

            # (Your original `detect_all_gammas`, `detect_gamma`, `inline_callee_core`,
            # `Env`, `freshen`, `rewrite`, and `prefix?` methods go here, unchanged)
            class Env
              def initialize = @frames = []
              def axes = @frames.map { _1[:axis] }

              def push(loop_ins)
                @frames << { axis: loop_ins.attributes[:axis], el: loop_ins.attributes[:as_element], idx: loop_ins.attributes[:as_index] }
              end

              def pop = @frames.pop
              def reg_for_axis(axis) = @frames.reverse.find { _1[:axis] == axis } || raise("no element for #{axis}")
            end

            def detect_all_gammas(ops_by_decl) = ops_by_decl.transform_values { |p| detect_gamma(Array(p[:operations])) }
            GammaInfo = Struct.new(:start_idx, :axes, :axis_regs, keyword_init: true)
            def detect_gamma(ops)
              frames = []
              ops.each do |ins|
                case ins.opcode
                when :LoopStart
                  frames << { axis: ins.attributes[:axis], el: ins.attributes[:as_element], idx: ins.attributes[:as_index] }
                when :LoopEnd
                  frames.pop
                when :Yield
                  axes = frames.map { _1[:axis] }
                  axis_regs = frames.map do |f|
                    { axis: f[:axis], el: f[:el], idx: f[:idx] }
                  end
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
              yield_index = ops.rindex { |ins| ins.opcode == :Yield } or raise "callee #{callee_name} has no Yield"
              yielded_reg = Array(ops[yield_index].inputs).first
              first_loop_index = ops.index { |ins| ins.opcode == :LoopStart }
              return [ops[0...yield_index], yielded_reg, info.axis_regs] unless first_loop_index

              prologue = ops[0...first_loop_index]
              main_part = ops[first_loop_index...yield_index]
              inner_body = []
              open_gamma = 0
              kind_stack = []
              main_part.each do |ins|
                case ins.opcode
                when :LoopStart
                  if open_gamma < k && ins.attributes[:axis] == axes[open_gamma]
                    kind_stack << :gamma
                    open_gamma += 1
                  else
                    kind_stack << :inner
                    inner_body << ins
                  end
                when :LoopEnd
                  kind = kind_stack.pop or raise "unbalanced loops in #{callee_name}"
                  inner_body << ins if kind == :inner
                else
                  inner_body << ins
                end
              end
              [prologue + inner_body, yielded_reg, info.axis_regs]
            end

            def freshen(block_ops, reg_map, pre_map: {})
              acc_map = {}
              new_ops = block_ops.map do |ins|
                res = ins.result_register
                reg_map[res] ||= @ids.generate_temp if res
                new_inputs = Array(ins.inputs).map do |r|
                  r1 = pre_map.fetch(r, r)
                  reg_map.fetch(r1, r1)
                end
                attrs = (ins.attributes || {}).dup
                case ins.opcode
                when :DeclareAccumulator
                  original_acc = ins.result_register
                  acc_map[original_acc] ||= @ids.generate_acc
                  res = acc_map[original_acc]
                when :Accumulate
                  original_acc = ins.result_register
                  acc_map[original_acc] ||= @ids.generate_acc
                  res = acc_map[original_acc]
                when :LoadAccumulator
                  original_acc = ins.inputs.first
                  acc_map[original_acc] ||= @ids.generate_acc
                  new_inputs[0] = acc_map[original_acc]
                when :LoopStart
                  attrs[:id] = @ids.generate_loop_id
                end
                LIR::Instruction.new(opcode: ins.opcode, result_register: res ? reg_map.fetch(res, res) : nil, stamp: ins.stamp, inputs: new_inputs,
                                     immediates: ins.immediates, attributes: attrs, location: ins.location)
              end
              [acc_map, new_ops]
            end

            def rewrite(ins, _reg_map, rename)
              new_inputs = Array(ins.inputs).map do |r|
                rename.fetch(r, r)
              end
              LIR::Instruction.new(opcode: ins.opcode, result_register: ins.result_register, stamp: ins.stamp, inputs: new_inputs,
                                   immediates: ins.immediates, attributes: ins.attributes, location: ins.location)
            end

            def prefix?(pre, full) = pre.each_with_index.all? { |tok, i| full[i] == tok }
          end
        end
      end
    end
  end
end
