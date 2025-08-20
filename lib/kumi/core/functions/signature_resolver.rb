# frozen_string_literal: true

module Kumi
  module Core
    module Functions
      # Picks the best signature for a set of argument shapes.
      #
      # Key ideas:
      # - Split each arg into OUTER + CELL where CELL rank = required (non-flexible) dims in that arg's signature.
      # - Match only CELL against the signature (right-aligned).
      # - Keep OUTER via "lifting": reducers drop inner axes but preserve OUTER.
      # - Enforce OUTER compatibility for elementwise ops (join_policy nil), with broadcast of size-1 outer dims.
      # - Support NEP-20 flexible dims (?x) and broadcastable dims (x|1).
      # - Prefer exact match, then scalar extension, then broadcastable, then flexible-drop (high cost).
      class SignatureResolver
        Result = Struct.new(:signature, :score, :result_axes, :join_policy, :dropped_axes, :env, :effective_signature, keyword_init: true)

        class << self
          def choose(signatures:, arg_shapes:)
            arg_shapes = [] if arg_shapes.nil?
            validate_arg_shapes!(arg_shapes)

            # Normalize incoming shapes (Array<Symbol|Integer>) → Array<Array<Dimension>>
            normalized_args = arg_shapes.map { |shape| shape.map { |d| dim_of(d) } }

            candidates = signatures.filter_map do |sig|
              match = match_signature(sig, normalized_args)
              next unless match

              env, score, merged_outer_names, matched_vars = match.values_at(:env, :score, :outer, :matched_vars)

              out_axes = bind_out_axes(sig, env)
              dropped  = compute_dropped_axes(sig, env, matched_vars)

              # Sanity check arity
              raise SignatureMatchError, "arity mismatch: signature has #{sig.arity} args, got #{arg_shapes.length}" unless sig.arity == arg_shapes.length

              Result.new(
                signature: sig,
                score: score,
                result_axes: merged_outer_names + out_axes,
                join_policy: sig.join_policy,
                dropped_axes: dropped,
                env: env,
                effective_signature: {
                  in_shapes: sig.in_shapes.map { |dims| dims.map(&:name) },
                  out_shape: sig.out_shape.map(&:name),
                  join_policy: sig.join_policy
                }
              )
            end

            raise SignatureMatchError, mismatch_message(signatures, arg_shapes) if candidates.empty?

            candidates.min_by(&:score)
          end

          private

          # ---------- Matching pipeline ----------

          def match_signature(sig, normalized_args)
            return nil unless sig.arity == normalized_args.length

            # Split each arg into OUTER + CELL according to its own expected rank
            splits = sig.in_shapes.each_with_index.map do |expected, idx|
              cell_rank = required_rank(expected)
              outer, cell = split_outer_cell(normalized_args[idx], cell_rank)
              { outer: outer, cell: cell, expected: expected }
            end

            # 1) Match CELLs and build env
            env = {}
            score = 0
            matched_vars = Set.new

            splits.each do |sp|
              res = match_cell(sp[:cell], sp[:expected], env)
              return nil unless res

              env = res[:env]
              score += res[:score]
              matched_vars.merge(res[:matched_vars])
            end

            # 2) Enforce OUTER compatibility for elementwise ops (nil join_policy)
            outer_names, outer_cost = unify_outer_for_elementwise(sig.join_policy, splits.map { _1[:outer] })
            return nil if outer_names.is_a?(Symbol) && outer_names == :__outer_mismatch__

            score += outer_cost

            { env: env, score: score, outer: outer_names, matched_vars: matched_vars }
          end

          # ---------- CELL matching ----------

          def match_cell(got_cell, expected, env)
            # Scalar extension (empty cell → broadcast) - always has cost to prefer exact matches
            return { env: env, score: expected.empty? ? 2 : 3, matched_vars: Set.new } if got_cell.empty?

            gi = got_cell.length - 1
            ei = expected.length - 1
            score = 0
            matched_vars = Set.new
            new_env = env.dup

            while ei >= 0
              exp = expected[ei]

              if exp.flexible? && gi < 0
                # optional tail not present
                ei -= 1
                score += FLEX_DROP_COST
                next
              end

              return nil if gi < 0 # got exhausted and expected not flexible

              got = got_cell[gi]

              # Try to match got vs exp; possibly updates env
              m = match_dim(got, exp, new_env)
              if m
                new_env = m[:env]
                score += m[:score]
                matched_vars << exp.name if exp.named?
                gi -= 1
                ei -= 1
                next
              end

              # If expected is flexible, we may drop it
              if exp.flexible?
                ei -= 1
                score += FLEX_DROP_COST
                next
              end

              return nil
            end

            # Any extra leading dims in got_cell are fine (they were OUTER already)

            { env: new_env, score: score, matched_vars: matched_vars }
          end

          def match_dim(got, exp, env)
            # exact literals (same symbol/integer)
            return { env: env, score: 0 } if got == exp

            # fixed-size integers
            if got.fixed_size? && exp.fixed_size?
              return got.size == exp.size ? { env: env, score: 0 } : nil
            end

            # broadcastable dim (x|1) accepts got == 1 or scalar-like promotion
            if exp.broadcastable?
              return { env: env, score: BROADCAST_COST } if got.fixed_size? && got.size == 1
              # If got is a named axis, we allow it (treat as broadcastable match with cost)
              return { env: env, score: BROADCAST_COST } if got.named?
            end

            # named variable binding / unification across args
            if exp.named?
              unified = unify_binding(env[exp.name], got)
              return nil if unified == :__conflict__

              new_env = env.dup
              new_env[exp.name] = unified
              # prefer 0 on exact same-name, small cost if we had to prefer non-1 over 1
              add_cost = env.key?(exp.name) && env[exp.name] != unified ? OUTER_BCAST_COST : 0
              return { env: new_env, score: add_cost }
            end

            nil
          end

          # ---------- OUTER merging for elementwise ----------

          def unify_outer_for_elementwise(join_policy, outers)
            # Non-elementwise joins (e.g., :zip, :product) place no restriction on OUTER
            return [[], 0] if outers.all?(&:empty?)
            return [outers.first.map(&:name), 0] if join_policy

            # All non-scalar args must agree on OUTER up to broadcasting of size-1 dims.
            # We left-align OUTER (leading axes), merging across args.
            max_len = outers.map(&:length).max
            merged = []
            cost = 0

            (0...max_len).each do |i|
              dims_at_i = outers.map { |o| o[i] }.compact
              # pick a representative
              rep = dims_at_i.find { |d| d.named? } || dims_at_i.find { |d| d.fixed_size? && d.size != 1 } || dims_at_i.first
              # check compatibility
              dims_at_i.each do |d|
                next if same_dim?(d, rep)

                if (d.fixed_size? && d.size == 1) || (rep.fixed_size? && rep.size == 1)
                  cost += OUTER_BCAST_COST
                  next
                end
                # mismatch on named/non-1 dims
                return :__outer_mismatch__
              end
              merged << (rep.named? ? rep.name : rep.size)
            end

            [merged, cost]
          end

          # ---------- Result helpers ----------

          def bind_out_axes(sig, env)
            sig.out_shape.map { |d| d.named? && env[d.name] ? env[d.name].name : d.name }
          end

          # Only report truly dropped axes that were PRESENT in the match
          # (flexible '?j' that was absent should NOT appear as dropped).
          # We detect presence via matched_vars set.
          def compute_dropped_axes(sig, env, matched_vars)
            # dropped = (vars_seen_in_inputs) - (vars_used_in_output)
            out_vars = sig.out_shape.select(&:named?).map(&:name)
            (matched_vars.to_a - out_vars).map do |name|
              env[name] ? env[name].name : name
            end
          end

          # ---------- Small utilities ----------

          FLEX_DROP_COST     = 10
          BROADCAST_COST     = 3
          OUTER_BCAST_COST   = 2

          def required_rank(expected_dims)
            expected_dims.count { |d| !d.flexible? }
          end

          def split_outer_cell(got_dims, cell_rank)
            return [[], got_dims] if got_dims.length <= cell_rank

            split_at = got_dims.length - cell_rank
            [got_dims[0...split_at], got_dims[split_at..]]
          end

          def same_dim?(a, b)
            return true if a == b

            a.named? && b.named? && a.name == b.name
          end

          def unify_binding(existing, new_dim)
            return new_dim unless existing
            return existing if existing == new_dim
            # prefer non-1 over 1 for broadcast unification
            if existing.fixed_size? && existing.size == 1
              return new_dim
            elsif new_dim.fixed_size? && new_dim.size == 1
              return existing
            end
            # if both are named but different, conflict
            return :__conflict__ unless same_dim?(existing, new_dim)

            existing
          end

          def dim_of(x)
            case x
            when Dimension then x
            when Symbol    then Dimension.new(x)
            when Integer   then Dimension.new(x)
            else
              raise SignatureMatchError, "Invalid dimension: #{x.inspect}"
            end
          end

          def validate_arg_shapes!(arg_shapes)
            ok = arg_shapes.is_a?(Array) &&
                 arg_shapes.all? { |s| s.is_a?(Array) && s.all? { |a| a.is_a?(Symbol) || a.is_a?(Integer) } }
            raise SignatureMatchError, "arg_shapes must be arrays of symbols/integers, got: #{arg_shapes.inspect}" unless ok
          end

          def mismatch_message(signatures, arg_shapes)
            sigs = signatures.map(&:inspect).join(", ")
            shapes = arg_shapes.map { |ax| "(#{ax.join(',')})" }.join(", ")
            "no matching signature for shapes #{shapes} among [#{sigs}]"
          end
        end
      end
    end
  end
end
