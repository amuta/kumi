# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        class LoopValidatePass < IRValidatePass
          validates :loop_module, with: Kumi::IR::Loop::Validator
        end
      end
    end
  end
end
