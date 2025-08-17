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

        def concatenate(a, b, **_) = a + b
        def prepend(head, xs) = [head] + xs

        def diff(xs, **_)
          n = xs.length
          return [] if n < 2

          out = Array.new(n - 1)
          i = 0
          while i < n - 1
            out[i] = xs[i + 1] - xs[i]
            i += 1
          end
          out
        end

        def cumsum(xs, **_)
          acc = 0
          xs.map { |v| acc += v }
        end

        def searchsorted(edges, v, side: :right)
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
      end
    end
  end
end
