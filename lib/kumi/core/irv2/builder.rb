# frozen_string_literal: true

require "set"

module Kumi
  module Core
    module IRV2
      InputPlan = Struct.new(
        :source_path,     # Array<Symbol>
        :axes,            # Array<Symbol> (logical site axes)
        :dtype,           # Symbol/String
        :key_policy,      # Symbol
        :missing_policy,  # Symbol
        :axis_loops,      # Array<Hash>   [{axis:, kind:, key:, alias:, loop_idx:, ...}]
        :leaf_nav,        # Array<Hash>   [{kind: :field_leaf, key: "..."}, ...]
        :terminal,        # Hash          {kind: :element_leaf|:field_leaf|:none, ...}
        :path_fqn,        # String        "a.b.c"
        keyword_init: true
      )


      class Builder
        attr_reader :values, :exports

        def initialize
          @next_id = 0
          @values  = []
          @exports  = []
        end

        def load_input(path, stamp: nil) = emit(:LoadInput, [path], {}, stamp: stamp)
        def load_declaration(name, stamp: nil) = emit(:LoadDeclaration, [name], {}, stamp: stamp)
        def load_decl(name, stamp: nil)      = emit(:LoadDecl, [name], {}, stamp: stamp)
        def const(lit, stamp: nil)           = emit(:Const, [lit], {}, stamp: stamp)
        def align_to(v, target_axes, stamp: nil) = emit(:AlignTo, [v], { target_axes: Array(target_axes).map(&:to_s) }, stamp: stamp)
        def select(cond, then_v, else_v, stamp: nil) = emit(:Select, [cond, then_v, else_v], {}, stamp: stamp)
        def map(func, *values, stamp: nil)       = emit(:Map, values, { fn: func }, stamp: stamp)
        def reduce(func, val, axis, stamp: nil)  = emit(:Reduce, [val], { fn: func, axis: axis.to_s }, stamp: stamp)
        def construct_tuple(*vs, elem_stamps: nil) = emit(:ConstructTuple, vs, {}, elem_stamps: elem_stamps)
        def tuple_get(v, index, stamp: nil) = emit(:TupleGet, [v], { index: index }, stamp: stamp)

        def store(name, v)
          (@exports << [name, v]
           nil)
        end

        def dump
          [*values.map(&:to_s), *exports.map { |(n, v)| "Store #{n}, %#{v.id}" }].join("\n")
        end

        private

        def emit(op, args, attrs, stamp: nil, elem_stamps: nil)
          v = Value.new(@next_id, op, args, attrs, stamp: stamp, elem_stamps: elem_stamps)
          @values << v
          @next_id += 1
          v
        end
      end
    end
  end
end
