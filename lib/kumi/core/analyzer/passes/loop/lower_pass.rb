# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        module Loop
          class LowerPass < IRLowerPass
            lowers from: :vec_module, to: :loop_module
            reads :registry
            optional_reads :precomputed_plan_by_fqn, :cross_axes, :outer_axes

            private

            def lower(vec_module)
              context = {
                input_plans: precomputed_plan_by_fqn || {},
                registry: registry,
                cross_axes: get_state(:cross_axes, required: false) || {},
                outer_axes: get_state(:outer_axes, required: false) || {}
              }
              loop_module = Kumi::IR::Loop::Module.from_vec(vec_module, context: context)
              Kumi::IR::Loop::Pipeline.run(graph: loop_module, context: context)
            end
          end
        end
      end
    end
  end
end
