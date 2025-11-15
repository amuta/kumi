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
            super(inputs: [value], attributes: attrs, **kwargs)
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
            super(inputs: [source], attributes: attrs, **kwargs)
          end
        end

        class AxisIndex < Node
          opcode :axis_index

          def initialize(axis:, **kwargs)
            super(inputs: [], attributes: { axis: axis.to_sym }, **kwargs)
          end
        end

        class ArrayBuild < Node
          opcode :array_build

          def initialize(elements:, **kwargs)
            super(
              inputs: Array(elements),
              attributes: { size: Array(elements).size },
              **kwargs
            )
          end
        end

        class Fold < Node
          opcode :fold

          def initialize(fn:, arg:, **kwargs)
            super(inputs: [arg], attributes: { fn: fn.to_sym }, **kwargs)
          end
        end

        class Reduce < Node
          opcode :reduce

          def initialize(fn:, arg:, over_axes:, **kwargs)
            attrs = {
              fn: fn.to_sym,
              over_axes: Array(over_axes).map(&:to_sym)
            }
            super(inputs: [arg], attributes: attrs, **kwargs)
          end
        end

        class DeclRef < Node
          opcode :decl_ref

          def initialize(name:, **kwargs)
            super(inputs: [], attributes: { name: name.to_sym }, **kwargs)
          end
        end

        class ImportCall < Node
          opcode :import_call

          def initialize(fn_name:, source_module:, args:, mapping_keys:, **kwargs)
            attrs = {
              fn_name: fn_name.to_sym,
              source_module: source_module.to_s,
              mapping_keys: Array(mapping_keys).map(&:to_sym)
            }
            super(inputs: Array(args), attributes: attrs, **kwargs)
          end
        end

        class MakeObject < Node
          opcode :make_object

          def initialize(inputs:, keys:, **kwargs)
            super(
              inputs: Array(inputs),
              attributes: { keys: Array(keys).map(&:to_sym) },
              **kwargs
            )
          end
        end
      end
    end
  end
end
