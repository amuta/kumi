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

              {
                signature: sig,
                score: score,
                result_axes: sig.out_shape.map(&:name), # Convert Dimension objects to names for backward compatibility
                join_policy: sig.join_policy,
                dropped_axes: sig.dropped_axes.map(&:name) # Convert Dimension objects to names
              }
            end.compact

            raise SignatureMatchError, mismatch_message(signatures, arg_shapes) if candidates.empty?

            # Lower score is better: 0 = exact-everywhere, then number of broadcasts
            candidates.min_by { |c| c[:score] }
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
            # Handle flexible dimensions - can match if got is subset/superset
            if expected.any?(&:flexible?)
              return flexible_dimension_cost(got: got, expected: expected)
            end

            # Standard matching - shapes must be same length or scalar broadcast
            if Shape.scalar?(got)
              return Shape.scalar?(expected) ? 0 : 1 # scalar-to-vector broadcast cost = 1
            end

            return nil unless got.length == expected.length

            # Match each dimension pair
            total_cost = 0
            got.zip(expected).each do |got_dim, exp_dim|
              dim_cost = match_dimension_cost(got: got_dim, expected: exp_dim)
              return nil if dim_cost.nil?

              total_cost += dim_cost
            end

            total_cost
          end

          # Handle matching with flexible dimensions (NEP 20 ? modifier)
          def flexible_dimension_cost(got:, expected:)
            # This is complex - for now, implement basic flexible matching
            # Full implementation would require resolving which dimensions are omitted
            10 # High cost for flexible matching - prefer non-flexible when possible
          end

          # Calculate cost of matching one dimension against another
          def match_dimension_cost(got:, expected:)
            return 0 if got == expected # Exact match

            # Same name, different modifiers
            if got.name == expected.name
              if got.fixed_size? && expected.fixed_size?
                return got.size == expected.size ? 0 : nil # Fixed sizes must match exactly
              elsif got.fixed_size? || expected.fixed_size?
                return 2 # Mixed fixed/named has cost
              else
                return 0 # Same named dimension
              end
            end

            # Different names - check broadcastable
            if expected.broadcastable? && Shape.scalar?([got])
              return 3 # Broadcastable match has higher cost
            end

            nil # No match possible
          end

          # Check if join_policy constraints are satisfied
          def valid_join_policy?(sig, normalized_args)
            return true if sig.join_policy # :zip or :product allows different axes

            # nil join_policy: all non-scalar args must have compatible axes
            non_scalar_args = normalized_args.reject { |a| Shape.scalar?(a) }
            return true if non_scalar_args.empty?

            # All non-scalar arguments should have same dimension names (ignoring modifiers)
            first_names = non_scalar_args.first.map(&:name)
            non_scalar_args.all? { |arg| arg.map(&:name) == first_names }
          end

          def mismatch_message(signatures, arg_shapes)
            sigs = signatures.map(&:inspect).join(", ")
            "no matching signature for shapes #{pp_shapes(arg_shapes)} among [#{sigs}]"
          end

          def pp_shapes(shapes)
            shapes.map { |ax| "(#{ax.join(',')})" }.join(", ")
          end
        end
      end
    end
  end
end
