# frozen_string_literal: true

module Kumi
  module Kernels
    module Ruby
      module VectorStruct
        module_function

        def size(vec)
          vec&.size
        end

        def join_zip(left, right)
          raise NotImplementedError, "join operations should be implemented in IR/VM"
        end

        def join_product(left, right)
          raise NotImplementedError, "join operations should be implemented in IR/VM"
        end

        def align_to(vec, target_axes)
          raise NotImplementedError, "align_to should be implemented in IR/VM"
        end

        def lift(vec, indices)
          raise NotImplementedError, "lift should be implemented in IR/VM"
        end

        def flatten(*args)
          raise NotImplementedError, "flatten should be implemented in IR/VM"
        end

        def take(values, indices)
          raise NotImplementedError, "take should be implemented in IR/VM"
        end
      end
    end
  end
end