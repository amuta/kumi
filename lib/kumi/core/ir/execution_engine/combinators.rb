# frozen_string_literal: true

module Kumi
  module Core
    module IR
      module ExecutionEngine
        # Pure combinators for data transformation
        module Combinators
          # Broadcast scalar over vec (scalar→vec only)
          # @param s [Hash] scalar value {:k => :scalar, :v => value}
          # @param v [Hash] vector value {:k => :vec, :scope => [...], :rows => [...]}
          # @return [Hash] broadcasted vector
          def self.broadcast_scalar(s, v)
            raise "First arg must be scalar" unless s[:k] == :scalar
            raise "Second arg must be vec" unless v[:k] == :vec

            rows = v[:rows].map do |r|
              r.key?(:idx) ? { v: s[:v], idx: r[:idx] } : { v: s[:v] }
            end

            Values.vec(v[:scope], rows, v[:has_idx])
          end

          # Positional zip for same-scope vecs
          # @param vecs [Array<Hash>] vectors to zip together
          # @return [Hash] zipped vector
          def self.zip_same_scope(*vecs)
            raise "All arguments must be vecs" unless vecs.all? { |v| v[:k] == :vec }
            raise "All vecs must have same scope" unless vecs.map { |v| v[:scope] }.uniq.size == 1
            raise "All vecs must have same row count" unless vecs.map { |v| v[:rows].size }.uniq.size == 1
            return vecs.first if vecs.length == 1

            first_vec = vecs.first
            zipped_rows = first_vec[:rows].zip(*vecs[1..].map { |v| v[:rows] }).map do |row_group|
              combined_values = row_group.map { |r| r[:v] }
              result_row = { v: combined_values }
              result_row[:idx] = row_group.first[:idx] if row_group.first.key?(:idx)
              result_row
            end

            Values.vec(first_vec[:scope], zipped_rows, first_vec[:has_idx])
          end

          # Prefix-index alignment for rank expansion/broadcasting
          # @param tgt [Hash] target vector (defines output structure)
          # @param src [Hash] source vector (values to align)
          # @param to_scope [Array] target scope
          # @param require_unique [Boolean] enforce unique prefixes
          # @param on_missing [Symbol] :error or :nil policy
          # @return [Hash] aligned vector
          def self.align_to(tgt, src, to_scope:, require_unique: false, on_missing: :error)
            raise "align_to expects vecs with indices" unless [tgt, src].all? { |v| v[:k] == :vec && v[:has_idx] }

            to_rank = to_scope.length
            src_rank = src[:rows].first[:idx].length
            raise "scope not prefix-compatible: #{src_rank} > #{to_rank}" unless src_rank <= to_rank

            # Build prefix->value hash
            h = {}
            src[:rows].each do |r|
              k = r[:idx].first(src_rank)
              raise "non-unique prefix for align_to: #{k.inspect}" if require_unique && h.key?(k)

              h[k] = r[:v]
            end

            # Map target rows through alignment
            rows = tgt[:rows].map do |r|
              k = r[:idx].first(src_rank)
              if h.key?(k)
                { v: h[k], idx: r[:idx] }
              else
                case on_missing
                when :nil then { v: nil, idx: r[:idx] }
                when :error then raise "missing prefix #{k.inspect} in align_to"
                else raise "unknown on_missing policy: #{on_missing}"
                end
              end
            end

            Values.vec(to_scope, rows, true)
          end

          # Build hierarchical groups for lift operation
          # @param rows [Array<Hash>] rows with indices
          # @param depth [Integer] nesting depth
          # @return [Array] nested array structure
          # rows: [{ v: ..., idx: [i0,i1,...] }, ...] with lexicographically sorted :idx
          def self.group_rows(rows, depth = 0)
            return [] if rows.empty?
            raise ArgumentError, "depth < 0" if depth < 0

            if depth == 0
              return rows.first[:v] if rows.first[:idx].nil? || rows.first[:idx].empty?

              return rows.map { |r| r[:v] }
            end

            out = []
            i = 0
            n = rows.length
            while i < n
              head = rows[i][:idx].first
              j = i + 1
              j += 1 while j < n && rows[j][:idx].first == head

              tail = rows[i...j].map { |r| { v: r[:v], idx: r[:idx][1..-1] } }
              out << group_rows(tail, depth - 1)
              i = j
            end
            out
          end
        end
      end
    end
  end
end
