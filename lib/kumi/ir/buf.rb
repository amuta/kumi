# frozen_string_literal: true

module Kumi
  module IR
    module Buf
      class Instruction < Base::Instruction
        def allocation?
          opcode == :alloc_buffer
        end

        def deallocation?
          opcode == :free_buffer
        end
      end

      class Function < Base::Function; end

      class Module < Base::Module
        def self.from_loop(loop_module, **_opts)
          new(name: loop_module.name)
        end
      end

      class Builder < Base::Builder
        private

        def instruction_class
          Instruction
        end
      end
    end
  end
end
