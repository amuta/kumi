# frozen_string_literal: true

module Kumi
  module Kernels
    module Ruby
      module VectorStruct
        module_function

        def size(vec)
          vec&.size
        end

        # === Accessors / predicates ===

        def array_get(array, idx)
          raise IndexError, "array is nil" if array.nil?

          array.fetch(idx) # raises IndexError on OOB (null_policy: error)
        end

        def struct_get(obj, key)
          raise KeyError, "struct is nil" if obj.nil?

          k = key.is_a?(String) || key.is_a?(Symbol) ? key.to_sym : key
          if obj.respond_to?(:[]) # Hash-like
            raise KeyError, "missing key #{k.inspect}" unless obj.key?(k) || obj.key?(k.to_s)

            obj[k].nil? ? obj[k.to_s] : obj[k]
          else
            # OpenStruct or plain object
            raise KeyError, "missing key #{k.inspect}" unless obj.respond_to?(k)

            obj.public_send(k)

          end
        end

        def array_contains(array, value)
          return nil if array.nil? # propagate

          array.include?(value)
        end

        def kumi_take(values, indices)
          raise ArgumentError, "values is nil" if values.nil?
          raise ArgumentError, "indices is nil" if indices.nil?

          if indices.is_a?(Array)
            indices.map { |idx| values[idx] }
          else
            values[indices]
          end
        end

        # === Structure helpers (simple Ruby fallbacks) ===
        # If/when VM handles these, you can keep these as thin helpers.

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

        # Flatten exactly one nesting level: [[a,b],[c]] => [a,b,c]
        def flatten(vec_2d)
          return nil if vec_2d.nil?

          vec_2d.flatten(1)
        end

        def kumi_concatenate(a, b, **_) = a + b
        def kumi_prepend(head, xs) = [head] + xs


        def kumi_searchsorted(edges, v, side: :right)
          lo = 0
          hi = edges.length
          if side == :left
            while lo < hi
              mid = (lo + hi) / 2
              edges[mid] < v ? lo = mid + 1 : hi = mid
            end
          else
            while lo < hi
              mid = (lo + hi) / 2
              edges[mid] <= v ? lo = mid + 1 : hi = mid
            end
          end
          lo
        end

        def kumi_take_along_axis(values, indices, axis: -1)
          # Simple implementation for last axis
          if indices.is_a?(Array)
            indices.map { |idx| values[idx] }
          else
            values[indices]
          end
        end
      end
    end
  end
end
