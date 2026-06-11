# frozen_string_literal: true

module Kumi
  module IR
    module Vec
      module Ops
        class Constant < Node
          opcode :constant

          def initialize(value:, **kwargs)
            super(inputs: [], attributes: { value: value }, **kwargs)
          end
        end

        class LoadInput < Node
          opcode :load_input

          def initialize(key:, chain: [], **kwargs)
            attrs = {
              key: key.to_sym,
              chain: Array(chain).map(&:to_s)
            }
            super(inputs: [], attributes: attrs, **kwargs)
          end
        end

        class LoadField < Node
          opcode :load_field

          def initialize(object:, field:, **kwargs)
            super(inputs: [object], attributes: { field: field.to_sym }, **kwargs)
          end
        end

        class Map < Node
          opcode :map

          def initialize(fn:, args:, **kwargs)
            super(inputs: Array(args), attributes: { fn: fn.to_sym }, **kwargs)
          end
        end

        class Select < Node
          opcode :select

          def initialize(cond:, on_true:, on_false:, **kwargs)
            super(inputs: [cond, on_true, on_false], **kwargs)
          end
        end

        class AxisBroadcast < Node
          opcode :axis_broadcast

          def initialize(value:, from_axes:, to_axes:, **kwargs)
            attrs = {
              from_axes: Array(from_axes).map(&:to_sym),
              to_axes: Array(to_axes).map(&:to_sym)
            }
            super(inputs: [value], attributes: attrs, axes: attrs[:to_axes], **kwargs)
          end
        end

        class AxisShift < Node
          POLICIES = %i[wrap clamp zero].freeze
          opcode :axis_shift

          def initialize(source:, axis:, offset:, policy:, **kwargs)
            policy = policy.to_sym
            raise ArgumentError, "invalid policy #{policy}" unless POLICIES.include?(policy)

            attrs = {
              axis: axis.to_sym,
              offset: Integer(offset),
              policy: policy
            }
            axes = kwargs[:axes] || extract_axes(source)
            super(inputs: [source], attributes: attrs, axes:, **kwargs)
          end

          private

          def extract_axes(source)
            source.respond_to?(:axes) ? source.axes : []
          end
        end

        class AxisIndex < Node
          opcode :axis_index

          def initialize(axis:, **kwargs)
            super(inputs: [], attributes: { axis: axis.to_sym }, **kwargs)
          end
        end

        class Reduce < Node
          opcode :reduce

          def initialize(fn:, arg:, over_axes:, **kwargs)
            attrs = {
              fn: fn.to_sym,
              over_axes: Array(over_axes).map(&:to_sym)
            }
            axes = kwargs[:axes] || derive_axes(arg, attrs[:over_axes])
            super(inputs: [arg], attributes: attrs, axes:, **kwargs)
          end

          private

          def derive_axes(arg, over_axes)
            source_axes = arg.respond_to?(:axes) ? Array(arg.axes) : []
            source_axes.reject { |axis| over_axes.include?(axis) }
          end
        end

        class MakeObject < Node
          opcode :make_object

          def initialize(inputs:, keys:, **kwargs)
            attributes = { keys: Array(keys).map(&:to_sym) }
            super(inputs: Array(inputs), attributes:, **kwargs)
          end
        end
      end
    end
  end
end
