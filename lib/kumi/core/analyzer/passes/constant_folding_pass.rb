# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        class ConstantFoldingPass < PassBase
          NAST = Kumi::Core::NAST

          def run(errors)
            nast_module = get_state(:nast_module, required: true)
            order = get_state(:evaluation_order, required: true)
            @registry = get_state(:registry, required: true)

            debug "\n[FOLD] Starting constant folding pass..."

            folder = Folder.new(self, nast_module, order, @registry)
            optimized_module, changed = folder.fold

            if changed
              debug "[FOLD] Pass made changes."
            else
              debug "[FOLD] Pass made no changes. Nothing to do."
            end

            # Always update the state, as the pass returns a new module object.
            state.with(:nast_module, optimized_module)
          end
        end
      end
    end
  end
end
