# frozen_string_literal: true

module Kumi
  module Kernels
    module Ruby
      module MaskScalar
        module_function

        def where(condition, if_true, if_false)
          condition ? if_true : if_false
        end
      end
    end
  end
end