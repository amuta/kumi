# frozen_string_literal: true

module Kumi
  module IR
    module Vec
      class Instruction < Base::Instruction
        def vector_width
          attributes[:width]
        end

        def mask?
          attributes[:mask] == true
        end
      end

      class Function < Base::Function; end

      class Module < Base::Module
        def self.from_buf(buf_module, **_opts)
          new(name: buf_module.name)
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
