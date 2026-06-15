# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        module Vec
          class LowerPass < IRLowerPass
            lowers from: :df_module, to: :vec_module

            private

            def lower(df_module)
              vec_module = Kumi::IR::Vec::Module.from_df(df_module)
              Kumi::IR::Vec::Pipeline.run(graph: vec_module, context: {})
            end
          end
        end
      end
    end
  end
end
