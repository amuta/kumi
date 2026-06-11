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

              context = {
                input_plans: get_state(:precomputed_plan_by_fqn, required: false) || {},
                registry: get_state(:registry, required: true)
              }
              loop_module = Kumi::IR::Loop::Module.from_vec(vec_module, context: context)
              optimized = Kumi::IR::Loop::Pipeline.run(graph: loop_module, context: context)
              state.with(:loop_module, optimized.freeze)
            end
          end
        end
      end
    end
  end
end
