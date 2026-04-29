# frozen_string_literal: true

require "kumi/ir/loop"

module Kumi
  module Core
    module Analyzer
      module Passes
        module Loop
          class LowerPass < PassBase
            def run(_errors)
              vec_module = get_state(:vec_module, required: false)
              return state unless vec_module

              loop_module = Kumi::IR::Loop::Module.from_vec(vec_module)
              optimized = Kumi::IR::Loop::Pipeline.run(graph: loop_module, context: {})
              state.with(:loop_module, optimized.freeze)
            end
          end
        end
      end
    end
  end
end
