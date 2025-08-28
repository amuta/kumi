# frozen_string_literal: true

require "set"

module Kumi
  module Core
    module IRV2
      InputPlan = Struct.new(:path, :axes, :dtype, :key_policy, :on_missing, :access_chain, keyword_init: true)

      ChainStep = Struct.new(:kind, :key, :axis, :dtype, keyword_init: true)

      class Builder
        attr_reader :values, :stores

        def initialize
          @next_id = 0
          @values  = []
          @stores  = []
        end

        def load_input(path)                 = emit(:LoadInput, [path], {})
        def load_param(name)                 = emit(:LoadParam, [name], {})
        def load_decl(name)                  = emit(:LoadDecl, [name], {})
        def const(lit)                       = emit(:Const, [lit], {})
        def align_to(v, axes_tokens)         = emit(:AlignTo, [v], { axes: axes_tokens })
        def map(kernel, *vs)                 = emit(:Map, vs, { op: kernel })
        def reduce(kernel, v, last_axis)     = emit(:Reduce, [v], { op: kernel, last_axis: last_axis })
        def construct_tuple(*vs)             = emit(:ConstructTuple, vs, {})
        def tuple_get(v, index)              = emit(:TupleGet, [v], { index: index })

        def store(name, v)
          (@stores << [name, v]
           nil)
        end

        def input_plan(path:, axes:, dtype:, access_chain:, key_policy: "indifferent", on_missing: "error")
          InputPlan.new(
            path: path,
            axes: axes,
            dtype: dtype,
            key_policy: key_policy,
            on_missing: on_missing,
            access_chain: access_chain
          )
        end

        def chain_step(kind:, key:, axis: nil, dtype: nil)
          ChainStep.new(
            kind: kind,
            key: key,
            axis: axis,
            dtype: dtype
          )
        end

        def dump
          [*values.map(&:to_s), *stores.map { |(n, v)| "Store #{n}, %#{v.id}" }].join("\n")
        end

        private

        def emit(op, args, attrs)
          v = Value.new(@next_id, op, args, attrs)
          @values << v
          @next_id += 1
          v
        end
      end
    end
  end
end
