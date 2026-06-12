# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        module Codegen
          class LoopRubyPass < PassBase
            reads :loop_module, :registry, :schema_digest
            writes :ruby_codegen_files

            def run(_errors)
              loop_module = get_state(:loop_module, required: true)
              registry = get_state(:registry, required: true)
              schema_digest = get_state(:schema_digest)

              emitter = Codegen::Loop::Ruby::Emitter.new(registry)
              src = emitter.emit(loop_module, schema_digest: schema_digest)

              state.with(:ruby_codegen_files, { "codegen.rb" => src })
            end
          end
        end
      end
    end
  end
end
