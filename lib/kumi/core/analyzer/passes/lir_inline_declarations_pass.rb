# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        # LIRInlineDeclarationsPass
        # -------------------------
        # Inlines LoadDeclaration when site axes == decl axes (strict).
        # - Detects callee Γ by skipping prologue and collecting consecutive LoopStart axes.
        # - Strips callee Γ (opening LoopStarts and their matching top-level LoopEnds).
        # - Drops the callee Yield and wires the yielded register into caller flow.
        # - Remaps callee loop element/index regs to caller regs by axis.
        # - Freshens temps/accumulators and regenerates loop ids inside the inlined body.
        #
        # Input : state[:lir_ops_by_decl]
        # Output: state.with(:lir_fused_ops_by_decl, fused_ops)
        class LIRInlineDeclarationsPass < PassBase
          LIR        = Kumi::Core::LIR
          MAX_PASSES = 30

          def run(_errors)
            current_ops = get_state(:lir_ops_by_decl)
            @ids        = LIR::Ids.new # Use a single ID generator for the entire process.

            MAX_PASSES.times do
              new_ops, changed = run_one_pass(current_ops)

              unless changed
                # Success: converged.
                return state.with(:lir_fused_ops_by_decl, new_ops.freeze)
              end

              current_ops = new_ops
            end

            raise "LIR inlining did not converge after #{MAX_PASSES} passes."
          end

          private

          # Performs a single pass of inlining over all declarations.
          # Returns [new_ops_by_decl, changed_flag]
          def run_one_pass(ops_by_decl)
            @ops_by_decl = ops_by_decl # Set instance var for helpers to use
            @gamma       = detect_all_gammas(@ops_by_decl)

            changed = false
            fused = {}
            @ops_by_decl.each do |name, payload|
              original_ops = Array(payload[:operations])
              inlined_ops = inline_decl(name, original_ops)
              fused[name] = { operations: inlined_ops }
              changed ||= (inlined_ops != original_ops)
            end

            [fused, changed]
          end

          def detect_all_gammas(ops_by_decl)
            ops_by_decl.transform_values do |payload|
              detect_gamma(Array(payload[:operations]))
            end
          end

          GammaInfo = Struct.new(:start_idx, :axes, :axis_regs, keyword_init: true)

          # Detect Γ after any prologue. Γ = maximal prefix of consecutive LoopStart.
          # Returns GammaInfo with:
          #   - start_idx: index of first LoopStart (or nil if no loops)
          #   - axes:      [:axis, ...] in order
          #   - axis_regs: [{axis:, el:, idx:}, ...] for element/index registers
          def detect_gamma(ops)
            frames = [] # [{axis:, el:, idx:}, ...]
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
                return GammaInfo.new(start_idx: nil, axes:, axis_regs:)
              end
            end
            # No yield? treat as empty Γ.
            GammaInfo.new(start_idx: nil, axes: [], axis_regs: [])
          end

          def inline_callee_core(callee_name)
            ops  = Array(@ops_by_decl.fetch(callee_name)[:operations])
            info = @gamma.fetch(callee_name)
            axes = info.axes
            k    = axes.length

            # Special case: scalar decl (k == 0) → body is ops before Yield.
            if k == 0
              inner = []
              yielded = nil
              ops.each do |ins|
                if ins.opcode == :Yield
                  yielded = Array(ins.inputs).first
                  break
                else
                  inner << ins
                end
              end
              raise "callee #{callee_name} has no Yield" unless yielded

              return [inner, yielded, []]
            end

            inner      = []
            yielded    = nil
            open_gamma = 0
            # Stack tracks whether a loop frame is :gamma or :inner
            kind_stack = []

            ops.each do |ins|
              case ins.opcode
              when :LoopStart
                if open_gamma < k && ins.attributes[:axis] == axes[open_gamma]
                  # This LoopStart is the next Γ loop → strip
                  kind_stack << :gamma
                  open_gamma += 1
                  # do not emit
                else
                  # Inner loop (not a Γ loop) → keep
                  kind_stack << :inner
                  inner << ins
                end

              when :LoopEnd
                kind = kind_stack.pop or raise "unbalanced loops in #{callee_name}"
                inner << ins if kind == :inner

                # When we have closed all Γ frames and kind_stack empty or only pre-Γ,
                # we still continue; any following Γ closes will be classified as :gamma.

              when :Yield
                yielded = Array(ins.inputs).first
                # drop the yield itself

              else
                # Only keep instructions if we are inside a non-stripped, inner loop.
                inner << ins unless kind_stack.empty?
              end
            end

            raise "callee #{callee_name} has no Yield" unless yielded

            [inner, yielded, info.axis_regs]
          end

          # Per-caller environment: track current loop stack with axis + element/index regs
          class Env
            def initialize
              @frames = []
            end

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
                raise("no element for #{axis}")
            end
          end

          def inline_decl(_decl_name, ops)
            out      = []
            env      = Env.new
            reg_map  = {} # Master map for all freshened registers in this scope.
            rename   = {} # Maps LoadDeclaration result to inlined result.
            i = 0

            while i < ops.length
              ins = ops[i]
              case ins.opcode
              when :LoopStart
                env.push(ins)
                out << rewrite(ins, reg_map, rename)
              when :LoopEnd
                env.pop
                out << rewrite(ins, reg_map, rename)
              when :LoadDeclaration
                callee = ins.immediates&.first&.value&.to_sym
                decl_axes = ins.attributes&.fetch(:axes) { raise "LoadDeclaration #{callee} missing :axes" }
                site_axes = env.axes
                if prefix?(Array(decl_axes), site_axes)
                  body_ops, yielded_reg, callee_axis_regs = inline_callee_core(callee)

                  axis_remap = {}
                  callee_axis_regs.each do |r|
                    caller = env.reg_for_axis(r[:axis])
                    axis_remap[r[:el]]  = caller[:el]
                    axis_remap[r[:idx]] = caller[:idx]
                  end

                  # Pass the master reg_map to be updated.
                  _acc_map, fresh_ops = freshen(body_ops, reg_map, pre_map: axis_remap)

                  out.concat(fresh_ops)

                  if ins.result_register
                    mapped = reg_map.fetch(yielded_reg, axis_remap.fetch(yielded_reg, yielded_reg))
                    rename[ins.result_register] = mapped
                  end
                else
                  out << rewrite(ins, reg_map, rename)
                end
              else
                out << rewrite(ins, reg_map, rename)
              end
              i += 1
            end

            out
          end

          # Freshen registers and accumulator names in a block.
          # pre_map: reg -> reg (applied to inputs before fresh mapping)
          # reg_map: The master register map to update.
          # Returns [acc_map, new_ops]
          def freshen(block_ops, reg_map, pre_map: {})
            acc_map = {}

            new_ops = block_ops.map do |ins|
              res = ins.result_register
              # Use and update the shared reg_map.
              reg_map[res] ||= @ids.generate_temp if res

              new_inputs = Array(ins.inputs).map do |r|
                r1 = pre_map.fetch(r, r)
                reg_map.fetch(r1, r1)
              end

              attrs = (ins.attributes || {}).dup
              case ins.opcode
              when :DeclareAccumulator, :Accumulate, :LoadAccumulator
                name_key = ins.opcode == :Accumulate ? :accumulator : :name
                name = attrs[name_key]
                acc_map[name] ||= :"#{name}_#{@ids.generate_temp.to_s.sub(/^t/, '')}"
                attrs[name_key] = acc_map[name]
              when :LoopStart
                attrs[:id] = @ids.generate_loop_id
              end

              LIR::Instruction.new(
                opcode: ins.opcode,
                result_register: res ? reg_map[res] : nil,
                stamp: ins.stamp,
                inputs: new_inputs,
                immediates: ins.immediates,
                attributes: attrs,
                location: ins.location
              )
            end

            [acc_map, new_ops]
          end

          # Apply simple register renames to a single instruction
          def rewrite(ins, _reg_map, rename) # reg_map is unused here for now, but signature matches
            # Only use the `rename` map, which maps caller-scope registers
            # (%t7) to their final inlined values.
            new_inputs = Array(ins.inputs).map { |r| rename.fetch(r, r) }
            LIR::Instruction.new(
              opcode: ins.opcode,
              # A result register of a non-inlined instruction should not be renamed.
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
