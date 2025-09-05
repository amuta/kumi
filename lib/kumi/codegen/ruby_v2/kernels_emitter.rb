# frozen_string_literal: true

module Kumi
  module Codegen
    module RubyV2
      module KernelsEmitter
        module_function

        def render(bindings_ruby:)
          kernels = Array(bindings_ruby && bindings_ruby["kernels"])
          assigns = kernels.map do |k|
            id   = k.fetch("kernel_id")
            impl = k.fetch("impl")
            %(KERNELS[#{id.inspect}] = ( #{impl} ))
          end

          <<~RUBY
            KERNELS = {}
            #{assigns.join("\n")}

            def __call_kernel__(key, *args)
              fn = KERNELS[key]
              raise NotImplementedError, "kernel not found: \#{key}" unless fn
              fn.call(*args)
            end
          RUBY
        end
      end
    end
  end
end
