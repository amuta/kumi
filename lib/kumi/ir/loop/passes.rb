# frozen_string_literal: true

module Kumi
  module IR
    module Loop
      module Passes
        autoload :Support, "kumi/ir/loop/passes/support/structure"
        autoload :LoopFusion, "kumi/ir/loop/passes/loop_fusion"
        autoload :ArrayContraction, "kumi/ir/loop/passes/array_contraction"
      end
    end
  end
end
