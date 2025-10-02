module Kumi
  module Core
    module LIR
      class Emit
        def initialize(registry:, ids:, ops:)
          (@registry = registry
           @ids = ids
           @ops = ops)
        end

        def iconst(v) = push(Build.constant(value: Integer(v), dtype: :integer, ids: @ids))

        # Kernel bridge with explicit function ids
        def k_id(fn_id, args, out:)
          ins = Build.kernel_call(function: @registry.resolve_function(fn_id),
                                  args:, out_dtype: out, ids: @ids)
          push(ins)
        end

        # Integer arithmetic via canonical ids
        def add_i(a, b) = k_id("core.add", [a, b], out: :integer)
        def sub_i(a, b) = k_id("core.sub", [a, b], out: :integer)
        def mod_i(a, b) = k_id("core.mod", [a, b], out: :integer)
        def lt(a, b)    = k_id("core.lt",  [a, b], out: :boolean)
        def gt(a, b)    = k_id("core.gt",  [a, b], out: :boolean)
        def le(a, b)   = k_id("core.lte", [a, b], out: :boolean)
        def ge(a, b)   = k_id("core.gte", [a, b], out: :boolean)
        def and_(a, b) = k_id("core.and", [a, b], out: :boolean)

        # Clamp via canonical id
        def clamp(x, lo, hi, out:) = k_id("core.clamp", [x, lo, hi], out:)

        def length(coll) = push(Build.length(collection_register: coll, ids: @ids))
        def gather(arr, i, dt) = push(Build.gather(collection_register: arr, index_register: i, dtype: dt, ids: @ids))
        def select(c, t, f, dt) = push(Build.select(cond: c, on_true: t, on_false: f, out_dtype: dt, ids: @ids))

        def const(value, dtype)
          push(Build.constant(value: value, dtype: dtype, ids: @ids))
        end

        def wrap_index(i, off, nlen)
          i_plus = add_i(i, iconst(off))
          m1     = mod_i(i_plus, nlen)
          p2     = add_i(m1, nlen)
          mod_i(p2, nlen)
        end

        def clamp_index(j, nlen)
          hi = add_i(nlen, iconst(-1))
          clamp(j, iconst(0), hi, out: :integer)
        end

        private

        def push(ins)
          (@ops << ins
           ins.result_register)
        end
      end
    end
  end
end
