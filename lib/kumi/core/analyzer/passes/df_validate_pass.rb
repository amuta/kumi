# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        class DFValidatePass < IRValidatePass
          validates :df_module, with: Kumi::IR::DF::Validator,
                                unoptimized_key: :df_module_unoptimized, registry: true
        end
      end
    end
  end
end
