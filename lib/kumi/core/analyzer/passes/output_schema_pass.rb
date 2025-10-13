# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        class OutputSchemaPass < PassBase
          def run(errors)
            snast_module = get_state(:snast_module)
            return state unless snast_module

            hints = get_state(:hints)
            output_schema = build_output_schema(snast_module, hints)
            state.with(:output_schema, output_schema.freeze)
          end

          private

          def build_output_schema(snast_module, hints)
            snast_module.decls.each_with_object({}) do |(name, decl), acc|
              next if hints[name][:inline]
              acc[name] = build_output_field(decl)
            end
          end

          def build_output_field(decl)
            meta = decl.meta
            stamp = meta[:stamp] || {}

            {
              kind: meta[:kind],
              type: stamp[:dtype],
              axes: stamp[:axes] || []
            }
          end
        end
      end
    end
  end
end
