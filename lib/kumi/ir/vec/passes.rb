# frozen_string_literal: true

module Kumi
  module IR
    module Vec
      module Passes
        autoload :ConstantPropagation, "kumi/ir/vec/passes/constant_propagation"
        autoload :Gvn, "kumi/ir/vec/passes/gvn"
        autoload :AxisCanonicalization, "kumi/ir/vec/passes/axis_canonicalization"
        autoload :PeepholeSimplify, "kumi/ir/vec/passes/peephole_simplify"
        autoload :StencilDetection, "kumi/ir/vec/passes/stencil_detection"
        autoload :Dce, "kumi/ir/vec/passes/dce"
      end
    end
  end
end
