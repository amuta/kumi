# frozen_string_literal: true

require "date"

module Kumi
  module Kernels
    module Ruby
      module DatetimeScalar
        module_function

        def dt_add_days(d, n)
          d + n
        end

        def dt_diff_days(d1, d2)
          (d1 - d2).to_i
        end
      end
    end
  end
end