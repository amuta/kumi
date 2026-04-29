# frozen_string_literal: true

module Kumi
  module IR
    module Loop
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

        class KernelCall < Node
          opcode :kernel_call

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

        class MakeObject < Node
          opcode :make_object

          def initialize(inputs:, keys:, **kwargs)
            super(inputs: Array(inputs), attributes: { keys: Array(keys).map(&:to_sym) }, **kwargs)
          end

          def keys = attributes[:keys]
        end

        class Reduce < Node
          opcode :reduce

          def initialize(fn:, arg:, over_axes:, **kwargs)
            super(
              inputs: [arg],
              attributes: {
                fn: fn.to_sym,
                over_axes: Array(over_axes).map(&:to_sym)
              },
              **kwargs
            )
          end

          def reducer = attributes[:fn]
          def over_axes = attributes[:over_axes]
        end
      end
    end
  end
end
