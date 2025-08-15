# frozen_string_literal: true

module Kumi
  module Kernels
    module Ruby
      module StringScalar
        module_function

        def str_concat(a, b)
          "#{a}#{b}"
        end

        # policy: zip is enforced by planner/VM; body identical is fine
        def str_concat_zip(a, b)
          str_concat(a, b)
        end

        def str_length(s)
          s&.length
        end

        def str_contains(s, sub)
          return nil if s.nil? || sub.nil? # propagate
          s.include?(sub)
        end
      end
    end
  end
end