# frozen_string_literal: true

require "kumi/ir/df"

module Kumi
  module Core
    module Analyzer
      module Passes
        class DFValidatePass < PassBase
          def run(_errors)
            unoptimized = get_state(:df_module_unoptimized, required: false)
            optimized = get_state(:df_module, required: false)
            registry = get_state(:registry, required: false)

            Kumi::IR::DF::Validator.validate!(unoptimized, allow_fold: true, registry:) if unoptimized
            Kumi::IR::DF::Validator.validate!(optimized, registry:) if optimized

            state
          end
        end
      end
    end
  end
end
