# frozen_string_literal: true

module Kumi
  module Codegen
    module V2
      module Pipeline
        module DeclContext
          module_function
          def run(pack, decl)
            # With merged structure, everything is in the declaration itself
            spec = pack.fetch("declarations").find { |d| d["name"] == decl }
            inputs = pack.fetch("inputs")
            {
              name: decl,
              axes: spec.fetch("axes"),
              inputs: inputs,
              reduce_plans: spec.fetch("reduce_plans", []),
              inline: spec.fetch("inlining_decisions", {}),
              schedule: spec.fetch("site_schedule", {}),
              ops: spec.fetch("operations"),
              result_id: spec["result_op_id"]
            }
          end
        end
      end
    end
  end
end