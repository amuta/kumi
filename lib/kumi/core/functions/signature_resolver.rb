# frozen_string_literal: true

require_relative "errors"
require_relative "shape"
require_relative "signature"

module Kumi
  module Core
    module Functions
      # Given a set of signatures and actual argument shapes, pick the best match.
      # Supports NEP 20 extensions: fixed-size, flexible, and broadcastable dimensions.
      #
      # Inputs:
      #   signatures : Array<Signature> (with Dimension objects)
      #   arg_shapes : Array<Array<Symbol|Integer>>   e.g., [[:i], [:i]] or [[], [3]] or [[2, :i]]
      #
      # Returns:
      #   { signature:, result_axes:, join_policy:, dropped_axes:, effective_signature: }
      #
      # NEP 20 Matching rules:
      # - Arity must match exactly (before flexible dimension resolution).
      # - Fixed-size dimensions (integers) must match exactly.
      # - Flexible dimensions (?) can be omitted if not present in all operands.
      # - Broadcastable dimensions (|1) can match scalar or size-1 dimensions.
      # - For each param position, shapes are checked according to NEP 20 rules.
      # - We prefer exact matches, then flexible matches, then broadcast matches.
      class SignatureResolver
        class << self
          def choose(signatures:, arg_shapes:)
            # Handle empty arg_shapes for zero-arity functions
            arg_shapes = [] if arg_shapes.nil?
            sanity_check_args!(arg_shapes)

            candidates = signatures.map do |sig|
              score = match_score(sig, arg_shapes)
              next if score.nil?

              # Convert arg_shapes to normalized Dimension arrays for environment building
              normalized_args = arg_shapes.map { |shape| normalize_shape(shape) }
              env = build_dimension_environment(sig, normalized_args)
              next if env.nil?  # Skip candidates with dimension conflicts

              {
                signature: sig,
                score: score,
                result_axes: sig.out_shape.map(&:name), # Convert Dimension objects to names for backward compatibility
                join_policy: sig.join_policy,
                dropped_axes: sig.dropped_axes.map { |name| name.is_a?(Symbol) ? name : name.to_sym }, # Convert to symbols
                env: env
              }
            end.compact

            raise SignatureMatchError, mismatch_message(signatures, arg_shapes) if candidates.empty?

            # Lower score is better: 0 = exact-everywhere, then number of broadcasts
            best = candidates.min_by { |c| c[:score] }
            
            # Add effective signature and environment for analyzer/lowering
            best[:effective_signature] = {
              in_shapes: best[:signature].in_shapes.map { |dims| dims.map(&:name) },
              out_shape: best[:signature].out_shape.map(&:name),
              join_policy: best[:signature].join_policy
            }
            # env is already included from candidate building
            
            best
          end

          private

          def sanity_check_args!(arg_shapes)
            unless arg_shapes.is_a?(Array) &&
                   arg_shapes.all? { |s| s.is_a?(Array) && s.all? { |a| a.is_a?(Symbol) || a.is_a?(Integer) } }
              raise SignatureMatchError, "arg_shapes must be an array of dimension arrays (symbols or integers), got: #{arg_shapes.inspect}"
            end
          end

          # Returns an integer "broadcast cost" or nil if not matchable.
          # Lower score = better match: 0 = exact, then increasing cost for broadcasts/flexibility
          def match_score(sig, arg_shapes)
            return nil unless sig.arity == arg_shapes.length

            # Convert arg_shapes to normalized Dimension arrays for comparison
            normalized_args = arg_shapes.map { |shape| normalize_shape(shape) }

            # Try to match each argument against its expected signature shape
            cost = 0
            sig.in_shapes.each_with_index do |expected_dims, idx|
              got_dims = normalized_args[idx]
              arg_cost = match_argument_cost(got: got_dims, expected: expected_dims)
              return nil if arg_cost.nil?

              cost += arg_cost
            end

            # Additional checks for join_policy constraints
            return nil unless valid_join_policy?(sig, normalized_args)

            cost
          end

          private

          # Convert a shape array (symbols/integers) to normalized Dimension array
          def normalize_shape(shape)
            shape.map do |dim|
              case dim
              when Symbol
                Dimension.new(dim)
              when Integer
                Dimension.new(dim)
              else
                raise SignatureMatchError, "Invalid dimension type: #{dim.class}"
              end
            end
          end

          # Calculate cost of matching one argument against expected dimensions
          def match_argument_cost(got:, expected:)
            # Handle scalar first
            if got.empty?
              return expected.empty? ? 0 : (expected.any?(&:flexible?) ? 10 : 1) # scalar broadcast or flexible-tail
            end

            # Try strict matching first if no flexible dimensions
            if !expected.any?(&:flexible?) && got.length == expected.length
              total = 0
              got.zip(expected).each do |g, e|
                c = match_dimension_cost(got: g, expected: e)
                return nil if c.nil?
                total += c
              end
              return total
            end

            # Use right-aligned flexible matching
            right_align_match(got: got, expected: expected)
          end

          # Right-aligned matching for flexible dimensions (NEP 20 ? modifier)
          def right_align_match(got:, expected:)
            gi = got.length - 1
            ei = expected.length - 1
            cost = 0

            while ei >= 0
              exp = expected[ei]

              if exp.flexible? && gi < 0
                # optional tail dimension that we don't have → ok, consume expected only
                ei -= 1
                cost += 10
                next
              end

              return nil if gi < 0 # ran out of got dims and exp wasn't flexible

              got_dim = got[gi]
              dim_cost = match_dimension_cost(got: got_dim, expected: exp)
              if dim_cost.nil?
                # if exp is flexible, we can try to drop it
                if exp.flexible?
                  ei -= 1
                  cost += 10
                  next
                else
                  return nil
                end
              else
                cost += dim_cost
                gi -= 1
                ei -= 1
              end
            end

            # if we still have leftover got dims, argument is longer than expected → not a match
            return nil if gi >= 0

            cost
          end

          # Calculate cost of matching one dimension against another
          def match_dimension_cost(got:, expected:)
            return 0 if got == expected # Exact match

            # Fixed-size equality
            if got.fixed_size? && expected.fixed_size?
              return got.size == expected.size ? 0 : nil
            end

            # Same symbolic name (ignoring modifiers) → ok unless one is fixed and the other isn't (penalize)
            if got.named? && expected.named? && got.name == expected.name
              return (got.fixed_size? || expected.fixed_size?) ? 2 : 0
            end

            # Broadcastable expected dim accepts scalar or size-1
            if expected.broadcastable?
              # scalar at argument level would have been handled in match_argument_cost
              # so here we check for size-1 fixed dimensions
              return 3 if got.fixed_size? && got.size == 1
              # Named dimensions that could be size-1 at runtime also get broadcast cost
              return 3 if got.named?
            end

            nil # No match possible
          end

          # Check if join_policy constraints are satisfied
          def valid_join_policy?(sig, normalized_args)
            return true if sig.join_policy # :zip or :product allows different axes

            # nil join_policy: check if dimension names are consistent
            non_scalar_args = normalized_args.reject { |a| Shape.scalar?(a) }
            return true if non_scalar_args.empty?

            # For nil join_policy, we allow different dimension names if:
            # 1. All args have same dimension names (element-wise operations), OR
            # 2. The constraint solver can validate cross-dimensional consistency (like matmul)
            first_names = non_scalar_args.first.map(&:name)
            same_names = non_scalar_args.all? { |arg| arg.map(&:name) == first_names }
            
            return true if same_names
            
            # If dimension names differ, check if constraint solver can handle it
            # This allows operations like matmul where dimensions are linked across arguments
            env = build_dimension_environment(sig, normalized_args)
            !env.nil?
          end

          def mismatch_message(signatures, arg_shapes)
            sigs = signatures.map(&:inspect).join(", ")
            "no matching signature for shapes #{pp_shapes(arg_shapes)} among [#{sigs}]"
          end

          def pp_shapes(shapes)
            shapes.map { |ax| "(#{ax.join(',')})" }.join(", ")
          end

          # Build dimension environment by checking consistency of named dimensions across arguments
          def build_dimension_environment(sig, normalized_args)
            env = {}
            
            # Walk all expected dimensions across all arguments
            sig.in_shapes.each_with_index do |expected_shape, arg_idx|
              got_shape = normalized_args[arg_idx] || []
              
              expected_shape.each_with_index do |exp_dim, dim_idx|
                next unless exp_dim.named? && dim_idx < got_shape.length
                
                got_dim = got_shape[dim_idx]
                dim_name = exp_dim.name
                
                # Check for consistency: same dimension name must map to same concrete value
                if env.key?(dim_name)
                  # If we've seen this dimension name before, it must match
                  if env[dim_name] != got_dim
                    return nil  # Inconsistent binding - signature doesn't match
                  end
                else
                  # First time seeing this dimension name - record the binding
                  env[dim_name] = got_dim
                end
              end
            end
            
            env
          end
        end
      end
    end
  end
end
