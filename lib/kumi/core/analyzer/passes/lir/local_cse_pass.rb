# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        module LIR
          # LIRLocalCSEPass
          # ---------------
          # Tiny, safe, per-declaration CSE:
          # - Deduplicates pure ops only (see PURE)
          # - Renames later uses to the first result (within a declaration)
          # - Ignores control/side-effect ops (loops, accums, yield)
          #
          # In : state[:lir_02_inlined_ops_by_decl]
          # Out: state.with(:lir_03_cse, ...)
          class LocalCSEPass < PassBase
            LIR = Kumi::Core::LIR

            def run(_errors)
              ops_by_decl = get_state(:lir_module, required: true)
              out = {}

              ops_by_decl.each do |name, payload|
                out[name] = { operations: optimize_decl(Array(payload[:operations])) }
              end

              out.freeze
              state.with(:lir_module, out).with(:lir_03_cse, out)
            end

            private

            def optimize_decl(ops)
              rename = {}   # reg_old -> reg_new
              memo   = {}   # cse_key -> reg
              out    = []

              ops.each do |ins|
                ins = rewrite_inputs(ins, rename)

                if ins.pure? && ins.result_register
                  key = cse_key(ins)
                  if (prev = memo[key])
                    rename[ins.result_register] = prev
                    next # drop duplicate op
                  else
                    memo[key] = ins.result_register
                  end
                end

                out << ins
              end

              out
            end

            def rewrite_inputs(ins, rename)
              return ins if ins.inputs.nil? || ins.inputs.empty?

              LIR::Instruction.new(
                opcode: ins.opcode,
                result_register: ins.result_register,
                stamp: ins.stamp,
                inputs: ins.inputs.map { |r| rename.fetch(r, r) },
                immediates: ins.immediates,
                attributes: ins.attributes,
                location: ins.location
              )
            end

            def cse_key(ins)
              case ins.opcode
              when :Constant
                lit = ins.immediates&.first
                [:Constant, lit&.value, lit&.dtype || ins.stamp&.dtype]
              when :LoadInput
                key = ins.immediates&.first&.value
                [:LoadInput, key, ins.stamp&.dtype]                         # include dtype
              when :LoadField
                key = ins.immediates&.first&.value
                [:LoadField, ins.inputs, key, ins.stamp&.dtype]             # include dtype
              when :LoadDeclaration
                name = ins.immediates&.first&.value
                [:LoadDeclaration, name, ins.attributes&.fetch(:axes, nil), ins.stamp&.dtype]
              when :KernelCall
                fn = ins.attributes&.fetch(:fn, nil)
                [:KernelCall, fn, ins.inputs, ins.stamp&.dtype]
              when :Select
                [:Select, ins.inputs, ins.stamp&.dtype]
              when :MakeTuple
                [:MakeTuple, ins.inputs, ins.stamp&.dtype]
              when :MakeObject
                keys = (ins.immediates || []).map { |l| l.value }
                [:MakeObject, keys, ins.inputs, ins.stamp&.dtype]
              when :TupleGet
                idx = ins.immediates&.first&.value
                [:TupleGet, ins.inputs, idx, ins.stamp&.dtype]
              else
                # Fallback (shouldn't be hit due to PURE guard)
                [ins.opcode, ins.inputs,
                 (ins.immediates || []).map { |l| [l.value, l.dtype] },
                 filtered_attrs(ins.attributes), ins.stamp&.dtype]
              end
            end

            def filtered_attrs(attrs)
              return nil unless attrs

              attrs.reject { |k, _| k == :id } # drop volatile loop ids if ever present
            end
          end
        end
      end
    end
  end
end
