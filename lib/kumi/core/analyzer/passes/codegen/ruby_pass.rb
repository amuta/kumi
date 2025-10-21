# frozen_string_literal: true

require "yaml"

module Kumi
  module Core
    module Analyzer
      module Passes
        module Codegen
          class RubyPass < PassBase
            LIR = Kumi::Core::LIR

            def run(_errors)
              decls = get_state(:lir_module)
              manifest = get_state(:binding_manifest)[:ruby]
              schema_digest = get_state(:schema_digest)
              hints = get_state(:hints)
              # The codegen pass no longer needs direct access to the registry
              emitter = Codegen::Ruby::Emitter.new(manifest["kernels"], manifest["bindings"])

              decls = decls.reject { |n, _v| hints[n][:inline] }
              src = emitter.emit(decls, schema_digest:)

              files = { "codegen.rb" => src }
              state.with(:ruby_codegen_files, files)
            end
          end
        end
      end
    end
  end
end
