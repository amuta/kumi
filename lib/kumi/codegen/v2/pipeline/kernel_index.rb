# frozen_string_literal: true

module Kumi
  module Codegen
    module V2
      module Pipeline
        module KernelIndex
          module_function
          def run(pack, target: "ruby")
            Array(pack.dig("bindings", target, "kernels")).to_h { |k| [k.fetch("kernel_id"), k.fetch("impl")] }
          end
        end
      end
    end
  end
end