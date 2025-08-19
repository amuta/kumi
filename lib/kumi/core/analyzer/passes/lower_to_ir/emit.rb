# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        module LowerToIR
          module Emit
            def fresh
              @temp_seq += 1
            end

            def emit_const(val)
              @ops << Kumi::Core::IR::Ops.Const(val)
              @ops.length - 1
            end

            def emit_load_input(accessor_key, scope:, is_scalar:, has_idx:)
              @ops << Kumi::Core::IR::Ops.LoadInput(accessor_key, scope: scope, is_scalar: is_scalar, has_idx: has_idx)
              @ops.length - 1
            end

            def emit_ref(name)
              @ops << Kumi::Core::IR::Ops.Ref(name)
              @ops.length - 1
            end

            def emit_lift(to_scope, slot)
              @ops << Kumi::Core::IR::Ops.Lift(Array(to_scope), slot)
              @ops.length - 1
            end


            def emit_map(fn, *arg_slots)
              @ops << Kumi::Core::IR::Ops.Map(fn, arg_slots.size, *arg_slots)
              @ops.length - 1
            end

            def emit_reduce(fn, axis, result_scope, flatten_args, src_slot)
              @ops << Kumi::Core::IR::Ops.Reduce(fn, Array(axis), Array(result_scope), Array(flatten_args), src_slot)
              @ops.length - 1
            end

            def emit_array(slots)
              @ops << Kumi::Core::IR::Ops.Array(slots.size, *slots)
              @ops.length - 1
            end

            def emit_store(name, slot)
              @ops << Kumi::Core::IR::Ops.Store(name, slot)
            end

            def emit_guard_push(mask_slot)
              @ops << Kumi::Core::IR::Ops.GuardPush(mask_slot)
            end

            def emit_guard_pop
              @ops << Kumi::Core::IR::Ops.GuardPop
            end

            def emit_switch(cases_attr, default_slot)
              @ops << Kumi::Core::IR::Ops.Switch(cases_attr, default_slot)
              @ops.length - 1
            end
          end
        end
      end
    end
  end
end