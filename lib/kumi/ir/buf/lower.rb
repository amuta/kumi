# frozen_string_literal: true

module Kumi
  module IR
    module Buf
      class Lower
        def initialize(vec_module:)
          @vec_module = vec_module
        end

        def call
          buf_module = Buf::Module.new(name: @vec_module.name)
          @vec_module.each_function do |fn|
            buf_module.add_function(
              Buf::Function.new(
                name: fn.name,
                parameters: fn.parameters,
                blocks: fn.blocks,
                return_stamp: fn.return_stamp
              )
            )
          end
          buf_module
        end
      end
    end
  end
end
