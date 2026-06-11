# frozen_string_literal: true

require "kumi/ir/vec"

module Kumi
  module Core
    module Analyzer
      module Passes
        module Vec
          class LowerPass < PassBase
            def run(_errors)
              df_module = get_state(:df_module, required: false)
              return state unless df_module

              vec_module = Kumi::IR::Vec::Module.from_df(df_module)
              optimized = Kumi::IR::Vec::Pipeline.run(graph: vec_module, context: {})
              state.with(:vec_module, optimized.freeze)
            end
          end
        end
      end
    end
  end
end
