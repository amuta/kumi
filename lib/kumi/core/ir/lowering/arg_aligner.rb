# frozen_string_literal: true

module Kumi
  module Core
    module IR
      module Lowering
        # Aligns function call arguments for MAP:
        # - keeps scalars as-is
        # - AlignTo for prefix-compatible vectors
        # - Join + Project for cross-scope vectors (uses node metadata join_policy if available)
        class ArgAligner
          Result = Struct.new(:slots, :carrier_scope, :emitted)

          def initialize(shape_of:)
            @shape_of = shape_of # -> SlotShape
          end

          # args:
          #   ops:            mutable ops array
          #   arg_slots:      [Integer] - the slots for each original argument
          #   join_policy:    nil | :zip | :product   (from FunctionSignaturePass metadata)
          #   on_missing:     :error | :nil
          #
          # returns Result(slots:, carrier_scope:, emitted: [op_indexes])
          def align!(ops:, arg_slots:, join_policy:, on_missing: :error)
            aligned = arg_slots.dup
            shapes  = aligned.map { |s| @shape_of.call(s) }
            initial_ops_count = ops.size  # Track how many ops existed before we start

            vec_is = aligned.each_index.select { |i| shapes[i].kind == :vec }
            return Result.new(aligned, nil, []) if vec_is.size < 2

            carrier_i     = vec_is.max_by { |i| shapes[i].scope.length }
            carrier_scope = shapes[carrier_i].scope
            carrier_slot  = aligned[carrier_i]
            emitted       = []

            # Partition: prefix-compatible vs cross-scope
            prefix_compatible = []
            cross_scope_idx   = []
            vec_is.each do |i|
              next if i == carrier_i
              
              if shapes[i].scope == carrier_scope
                # Same scope as carrier - no alignment needed
                next
              end
              
              short, long = [shapes[i].scope, carrier_scope].sort_by(&:length)
              if long.first(short.length) == short
                prefix_compatible << i
              else
                cross_scope_idx << i
              end
            end

            # 1) AlignTo for prefix-compatible
            prefix_compatible.each do |i|
              ops << Kumi::Core::IR::Ops.AlignTo(
                carrier_slot, aligned[i],
                to_scope: carrier_scope, require_unique: true, on_missing: on_missing
              )
              # New slot number = next available slot after current maximum
              max_existing_slot = arg_slots.max + (ops.size - initial_ops_count - 1)
              new_slot = max_existing_slot + 1
              aligned[i] = new_slot
              emitted << new_slot
            end

            # 2) Join + Project for cross-scope
            if cross_scope_idx.any?
              raise "cross-scope map requires join_policy but none provided" unless join_policy

              join_slots = [aligned[carrier_i]] + cross_scope_idx.map { |idx| aligned[idx] }
              ops << Kumi::Core::IR::Ops.Join(*join_slots, policy: join_policy, on_missing: on_missing)
              max_existing_slot = arg_slots.max + (ops.size - initial_ops_count - 1)
              join_slot = max_existing_slot + 1
              emitted << join_slot

              # Build slot→column map
              col_for = {}
              join_slots.each_with_index { |slot, col| col_for[slot] = col }

              # Project each participating original arg to its own lane
              ([carrier_i] + cross_scope_idx).each do |i|
                ops << Kumi::Core::IR::Ops.Project(join_slot, col_for[aligned[i]])
                max_existing_slot = arg_slots.max + (ops.size - initial_ops_count - 1)
                project_slot = max_existing_slot + 1
                aligned[i] = project_slot
                emitted << project_slot
              end
            end

            Result.new(aligned, carrier_scope, emitted)
          end
        end
      end
    end
  end
end