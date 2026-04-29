# frozen_string_literal: true

require "kumi/ir/loop"

module Kumi
  module Core
    module Analyzer
      module Passes
        class LoopValidatePass < PassBase
          def run(_errors)
            loop_module = get_state(:loop_module, required: false)
            return state unless loop_module

            Kumi::IR::Loop::Validator.validate!(loop_module)
            state
          end
        end
      end
    end
  end
end
