# frozen_string_literal: true

module Kumi
  module Core
    module IR
      module ExecutionEngine
        # Value constructors and helpers for VM data representation
        module Values
          # Create a scalar value
          def self.scalar(v)
            { k: :scalar, v: v }
          end

          # Create a vector with scope and rows
          def self.vec(scope, rows, has_idx)
            rank = if has_idx
                     rows.empty? ? 0 : rows.first[:idx].length
                   # TODO: > Make sure this is not costly
                   # raise if rows.any? { |r| r[:idx].length != rank }
                   # rows = rows.sort_by { |r| r[:idx] } # one-time sort
                   else
                     0
                   end

            { k: :vec, scope: scope, rows: rows, has_idx: has_idx, rank: rank }
          end

          # Create a row with optional index
          def self.row(v, idx = nil)
            idx ? { v: v, idx: Array(idx) } : { v: v }
          end

          # Check if value is scalar
          def self.scalar?(val)
            val[:k] == :scalar
          end

          # Check if value is vector
          def self.vec?(val)
            val[:k] == :vec
          end
        end
      end
    end
  end
end
