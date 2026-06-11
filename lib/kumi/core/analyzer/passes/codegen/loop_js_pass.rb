# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        module Codegen
          class LoopJsPass < PassBase
            def run(_errors)
              loop_module = get_state(:loop_module, required: true)
              registry = get_state(:registry, required: true)
              schema_digest = get_state(:schema_digest)

              emitter = Codegen::Loop::Js::Emitter.new(registry)
              src = emitter.emit(loop_module, schema_digest: schema_digest)

              state.with(:javascript_codegen_files, { "codegen.mjs" => src })
            end
          end
        end
      end
    end
  end
end
