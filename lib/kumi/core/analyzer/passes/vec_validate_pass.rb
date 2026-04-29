# frozen_string_literal: true

require "kumi/ir/vec"

module Kumi
  module Core
    module Analyzer
      module Passes
        class VecValidatePass < PassBase
          def run(_errors)
            vec_module = get_state(:vec_module, required: false)
            return state unless vec_module

            Kumi::IR::Vec::Validator.validate!(vec_module)
            state
          end
        end
      end
    end
  end
end
