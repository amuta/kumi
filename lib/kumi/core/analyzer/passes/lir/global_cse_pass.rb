# frozen_string_literal: true

require "set"

module Kumi
  module Core
    module Analyzer
      module Passes
        module LIR
          class GlobalCSEPass < PassBase
            LIR = Kumi::Core::LIR

            def run(_errors)
              ops_by_decl = get_state(:lir_module, required: true)
              out = {}

              # --- FIX ---
              # Process each declaration with its own fresh set of maps.
              # This prevents optimizations from leaking across method boundaries.
              ops_by_decl.each do |name, payload|
                @value_map = {}  # cse_key -> canonical_result_register
                @rename_map = {} # old_register -> canonical_result_register
                out[name] = { operations: optimize_decl(Array(payload[:operations])) }
              end
              # --- END OF FIX ---

              out.freeze
              state.with(:lir_module, out.freeze).with(:lir_05_global_cse, out)
            end

            private

            def optimize_decl(ops)
              new_ops = []
              ops.each do |ins|
                rewritten_ins = rewrite_inputs(ins, @rename_map)

                if rewritten_ins.pure? && rewritten_ins.result_register
                  key = build_cse_key(rewritten_ins)

                  if (canonical_reg = @value_map[key])
                    @rename_map[rewritten_ins.result_register] = canonical_reg
                    next
                  else
                    @value_map[key] = rewritten_ins.result_register
                  end
                end

                new_ops << rewritten_ins
              end
              new_ops
            end

            def rewrite_inputs(ins, rename_map)
              return ins if ins.inputs.nil? || ins.inputs.empty?

              LIR::Instruction.new(
                opcode: ins.opcode, result_register: ins.result_register, stamp: ins.stamp,
                inputs: ins.inputs.map { |r| rename_map.fetch(r, r) },
                immediates: ins.immediates, attributes: ins.attributes, location: ins.location
              )
            end

            def build_cse_key(ins)
              canonical_inputs = Array(ins.inputs).map { |r| @rename_map.fetch(r, r) }
              case ins.opcode
              when :Constant
                lit = ins.immediates&.first
                [:Constant, lit&.value, lit&.dtype]
              when :LoadInput
                key = ins.immediates&.first&.value
                [:LoadInput, key]
              when :LoadField
                key = ins.immediates&.first&.value
                [:LoadField, canonical_inputs, key]
              when :KernelCall
                fn = ins.attributes&.fetch(:fn, nil)
                [:KernelCall, fn, canonical_inputs]
              when :Select then [:Select, canonical_inputs]
              when :MakeTuple then [:MakeTuple, canonical_inputs]
              else; [ins.opcode, canonical_inputs, (ins.immediates || []).map(&:value)]
              end
            end
          end
        end
      end
    end
  end
end
