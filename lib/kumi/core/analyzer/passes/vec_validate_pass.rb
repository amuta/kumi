# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        class VecValidatePass < IRValidatePass
          validates :vec_module, with: Kumi::IR::Vec::Validator
        end
      end
    end
  end
end
