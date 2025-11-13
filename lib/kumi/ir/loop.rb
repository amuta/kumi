# frozen_string_literal: true

module Kumi
  module IR
    module Loop
      OPCODES = %i[
        constant
        load_input
        load_field
        loop_start
        loop_end
        call
        select
        declare_accumulator
        accumulate
        load_accumulator
        make_tuple
        make_object
        yield
      ].freeze

      class Instruction < Base::Instruction
        def loop_control?
          %i[loop_start loop_end].include?(opcode)
        end

        def accumulator?
          %i[declare_accumulator accumulate load_accumulator].include?(opcode)
        end
      end

      class Function < Base::Function
        attr_reader :axes

        def initialize(axes: [], **kwargs)
          @axes = Array(axes).map(&:to_sym)
          super(**kwargs)
        end
      end

      class Module < Base::Module
        def self.from_dfir(df_graph, **_opts)
          new(name: df_graph.name)
        end
      end

      class Builder < Base::Builder
        def constant(value:, dtype:, result: nil, metadata: {})
          emit(:constant, result:, attributes: { dtype:, value: }, metadata:)
        end

        def loop(axis:, collection:, element:, index:, loop_id:, metadata: {})
          emit(
            :loop_start,
            inputs: [collection],
            attributes: { axis:, element:, index:, loop_id: },
            effects: Effects::CONTROL,
            metadata:
          )
        end

        def end_loop(metadata: {})
          emit(:loop_end, effects: Effects::CONTROL, metadata:)
        end

        private

        def instruction_class
          Instruction
        end
      end
    end
  end
end
