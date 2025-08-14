# frozen_string_literal: true

module Kumi
  module Kernels
    module Ruby
      module StringScalar
        module_function

        def str_concat(a, b)
          "#{a}#{b}"
        end

        def str_length(s)
          s&.length
        end
      end
    end
  end
end