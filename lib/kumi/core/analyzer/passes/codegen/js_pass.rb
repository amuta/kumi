# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        module Codegen
          class JsPass < PassBase
            def run(_errors)
              decls = get_state(:lir_module)
              manifest = get_state(:binding_manifest)[:javascript]
              schema_digest = get_state(:schema_digest)

              emitter = Codegen::Js::Emitter.new(manifest["kernels"], manifest["bindings"])
              src = emitter.emit(decls, schema_digest: schema_digest)

              files = { "codegen.js" => src }
              state.with(:javascript_codegen_files, files)
            end
          end
        end
      end
    end
  end
end
