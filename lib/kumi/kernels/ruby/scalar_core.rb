# frozen_string_literal: true

module Kumi
  module Kernels
    module Ruby
      module ScalarCore
        module_function

        def kumi_add(a, b)
          a + b
        end

        def kumi_sub(a, b)
          a - b
        end

        def kumi_mul(a, b)
          a * b
        end

        def kumi_div(a, b)
          a / b.to_f
        end

        def kumi_eq(a, b)
          a == b
        end

        def kumi_gt(a, b)
          a > b
        end

        def kumi_gte(a, b)
          a >= b
        end

        def kumi_lt(a, b)
          a < b
        end

        def kumi_lte(a, b)
          a <= b
        end

        def kumi_ne(a, b)
          a != b
        end

        def kumi_and(a, b)
          a && b
        end

        def kumi_or(a, b)
          a || b
        end

        def kumi_not(a)
          !a
        end

        def kumi_if(condition, then_val, else_val)
          condition ? then_val : else_val
        end
      end
    end
  end
end