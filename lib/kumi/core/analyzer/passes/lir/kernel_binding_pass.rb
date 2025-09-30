# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        module LIR
          class KernelBindingPass < PassBase
            # In:  state[:lir_module], state[:registry]
            # Out: state[:binding_manifest], state[:registry]
            def run(_errors)
              lir_decls = get_state(:lir_module)
              registry = get_state(:registry)

              # Generate binding manifest from the final LIR
              manifest_ruby = Binder.bind(lir_decls, registry, target: :ruby)
              manifest_js = Binder.bind(lir_decls, registry, target: :javascript)
              manifest = {
                ruby: manifest_ruby,
                javascript: manifest_js
              }

              state.with(:binding_manifest, manifest)
            end
          end
        end
      end
    end
  end
end
