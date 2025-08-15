# frozen_string_literal: true

module Kumi
  module Kernels
    module Ruby
      module StringScalar
        module_function

        # Supports 2 or 3 args (and future N), with null_policy: propagate
        def str_concat(*xs)
          return nil if xs.any?(&:nil?)
          xs.join
        end

        # zip policy is enforced by analyzer/VM; body identical is fine
        def str_concat_zip(*xs)
          str_concat(*xs)
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