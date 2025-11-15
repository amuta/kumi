# frozen_string_literal: true

require "kumi/ir/loop"

module Kumi
  module Core
    module Analyzer
      module Passes
        module Loop
          class LowerPass < PassBase
            def run(_errors)
              df_module = get_state(:df_module, required: false)
              return state unless df_module

              loop_context = {
                registry: get_state(:registry, required: false),
                input_table: get_state(:input_table, required: false),
                imported_schemas: get_state(:imported_schemas, required: false) || {},
                precomputed_plan_by_fqn: get_state(:precomputed_plan_by_fqn, required: false) || {}
              }

              loop_module = Kumi::IR::Loop::Module.from_dfir(df_module, context: loop_context)
              optimized = Kumi::IR::Loop::Pipeline.run(graph: loop_module, context: loop_context)

              state.with(:loop_module, optimized.freeze)
            end
          end
        end
      end
    end
  end
end
