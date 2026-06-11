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

          def initialize(key:, **kwargs)
            super(inputs: [], attributes: { key: key.to_sym }, **kwargs)
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

        class Ref < Node
          opcode :ref

          def initialize(value:, **kwargs)
            super(inputs: [value], **kwargs)
          end
        end

        class LoopStart < Node
          opcode :loop_start

          def initialize(source:, axis:, index:, **kwargs)
            super(
              inputs: [source],
              attributes: { axis: axis.to_sym, index: index },
              effects: [Base::Effects::CONTROL],
              **kwargs
            )
          end

          def axis = attributes[:axis]
          def index = attributes[:index]
        end

        class LoopEnd < Node
          opcode :loop_end

          def initialize(axis:, **kwargs)
            super(inputs: [], attributes: { axis: axis.to_sym }, effects: [Base::Effects::CONTROL], **kwargs)
          end

          def axis = attributes[:axis]
        end

        class ArrayInit < Node
          opcode :array_init

          def initialize(**kwargs)
            super(inputs: [], effects: [Base::Effects::MEMORY], **kwargs)
          end
        end

        class ArrayPush < Node
          opcode :array_push

          def initialize(array:, value:, **kwargs)
            super(inputs: [array, value], effects: [Base::Effects::MEMORY], **kwargs)
          end

          def array = inputs[0]
          def value = inputs[1]
        end

        class ArrayLen < Node
          opcode :array_len

          def initialize(array:, **kwargs)
            super(inputs: [array], **kwargs)
          end
        end

        class IndexRead < Node
          opcode :index_read

          def initialize(array:, index:, **kwargs)
            super(inputs: [array, index], **kwargs)
          end
        end

        class ShiftRead < Node
          POLICIES = %i[wrap clamp].freeze
          opcode :shift_read

          def initialize(array:, index:, length:, offset:, policy:, **kwargs)
            policy = policy.to_sym
            raise ArgumentError, "invalid shift policy #{policy}" unless POLICIES.include?(policy)

            super(
              inputs: [array, index, length],
              attributes: { offset: Integer(offset), policy: policy },
              **kwargs
            )
          end

          def offset = attributes[:offset]
          def policy = attributes[:policy]
        end

        class ShiftInBounds < Node
          opcode :shift_in_bounds

          def initialize(index:, length:, offset:, **kwargs)
            super(inputs: [index, length], attributes: { offset: Integer(offset) }, **kwargs)
          end

          def offset = attributes[:offset]
        end

        class AccInit < Node
          opcode :acc_init

          def initialize(fn:, init:, nil_init:, **kwargs)
            super(
              inputs: [],
              attributes: { fn: fn.to_sym, init: init, nil_init: nil_init },
              effects: [Base::Effects::STATE],
              **kwargs
            )
          end
        end

        class AccStep < Node
          opcode :acc_step

          def initialize(acc:, value:, fn:, nil_init:, **kwargs)
            super(
              inputs: [acc, value],
              attributes: { fn: fn.to_sym, nil_init: nil_init },
              effects: [Base::Effects::STATE],
              **kwargs
            )
          end

          def acc = inputs[0]
          def value = inputs[1]
        end

        class AccLoad < Node
          opcode :acc_load

          def initialize(acc:, **kwargs)
            super(inputs: [acc], **kwargs)
          end
        end
      end
    end
  end
end
