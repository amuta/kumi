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

          # Positional join of N vectors (zip policy)
          # @param vecs [Array<Hash>] vectors to join together
          # @param policy [Symbol] join policy (:zip or :product)
          # @param on_missing [Symbol] handling policy (:error or :nil)
          # @return [Hash] joined vector with combined rows
          def self.join_zip(vecs, on_missing: :error)
            raise "All arguments must be vecs" unless vecs.all? { |v| v[:k] == :vec }
            
            # Validate on_missing policy early
            unless [:error, :nil].include?(on_missing)
              raise "unknown on_missing policy: #{on_missing}"
            end
            
            return vecs.first if vecs.length == 1

            lengths = vecs.map { |v| v[:rows].size }
            if lengths.uniq.size > 1
              case on_missing
              when :error
                raise "Length mismatch in join_zip: #{lengths.inspect}"
              when :nil
                max_length = lengths.max
                vecs = vecs.map.with_index do |v, i|
                  if v[:rows].size < max_length
                    padded_rows = v[:rows] + Array.new(max_length - v[:rows].size) { { v: nil } }
                    Values.vec(v[:scope], padded_rows, v[:has_idx])
                  else
                    v
                  end
                end
              end
            end

            first_vec = vecs.first
            zipped_rows = first_vec[:rows].zip(*vecs[1..].map { |v| v[:rows] }).map do |row_group|
              combined_values = row_group.map { |r| r[:v] }
              result_row = { v: combined_values }
              
              # Handle indices: use the first available index, or create a synthetic one if has_idx is true
              has_idx = vecs.any? { |v| v[:has_idx] }
              if has_idx
                first_indexed_row = row_group.find { |r| r&.key?(:idx) }
                result_row[:idx] = first_indexed_row ? first_indexed_row[:idx] : []
              end
              
              result_row
            end

            # Determine output scope: concatenation of all input scopes
            output_scope = vecs.flat_map { |v| v[:scope] }
            has_idx = vecs.any? { |v| v[:has_idx] }

            Values.vec(output_scope, zipped_rows, has_idx)
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

          # Extract a specific column from a joined vector
          # vec: a joined vector where each row[:v] is an array of values
          # index: which column to extract (0-based)
          def self.project(vec, index)
            raise "Project operation: input must be a vector" unless vec[:k] == :vec
            
            projected_rows = vec[:rows].map do |row|
              row_values = row[:v]
              unless row_values.is_a?(Array)
                raise "Project operation: expected array values in joined vector, got #{row_values.class}"
              end
              
              if index >= row_values.length
                raise "Project operation: index #{index} out of bounds for row with #{row_values.length} values"
              end
              
              projected_value = row_values[index]
              row.key?(:idx) ? { v: projected_value, idx: row[:idx] } : { v: projected_value }
            end
            
            # The projected result should maintain the original scope structure but extract one component
            # For simplicity, we'll use the first scope component (this may need refinement)
            original_scope = vec[:scope]
            
            Values.vec(original_scope, projected_rows, vec[:has_idx])
          end
        end
      end
    end
  end
end
