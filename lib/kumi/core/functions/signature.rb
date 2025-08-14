# frozen_string_literal: true

module Kumi
  module Core
    module Functions
      # Signature is a small immutable value object describing a function's
      # vectorization contract with NEP 20 support.
      #
      # in_shapes: Array<Array<Dimension>>   e.g., [[Dimension.new(:i)], [Dimension.new(:i)]]
      # out_shape: Array<Dimension>          e.g., [Dimension.new(:i)], [Dimension.new(:i), Dimension.new(:j)], or []
      # join_policy: nil | :zip | :product
      # raw: original string, for diagnostics (optional)
      class Signature
        attr_reader :in_shapes, :out_shape, :join_policy, :raw

        def initialize(in_shapes:, out_shape:, join_policy: nil, raw: nil)
          @in_shapes   = deep_dup(in_shapes).freeze
          @out_shape   = out_shape.dup.freeze
          @join_policy = join_policy&.to_sym
          @raw         = raw
          validate!
          freeze
        end

        def arity = @in_shapes.length

        # Dimensions that appear in any input but not in output (i.e., reduced/dropped).
        def dropped_axes
          input_names = @in_shapes.flatten.map(&:name)
          output_names = @out_shape.map(&:name)
          (input_names - output_names).uniq.freeze
        end

        # True if any axis from inputs is dropped (common in aggregates).
        def reduction?
          !dropped_axes.empty?
        end

        def to_h
          {
            in_shapes: in_shapes.map(&:dup),
            out_shape: out_shape.dup,
            join_policy: join_policy,
            raw: raw
          }
        end

        def inspect
          "#<Signature #{format_signature}#{" @#{join_policy}" if join_policy}>"
        end

        def format_signature
          lhs = in_shapes.map { |dims| "(#{dims.map(&:to_s).join(',')})" }.join(",")
          rhs = "(#{out_shape.map(&:to_s).join(',')})"
          "#{lhs}->#{rhs}"
        end

        # Convert back to string representation for NEP-20 parser compatibility
        def to_signature_string
          sig_str = format_signature
          join_policy ? "#{sig_str}@#{join_policy}" : sig_str
        end

        private

        def validate!
          unless @in_shapes.is_a?(Array) && @in_shapes.all? { |s| s.is_a?(Array) }
            raise SignatureError, "in_shapes must be an array of dimension arrays"
          end

          @in_shapes.each_with_index do |dims, idx|
            validate_dimensions!(dims, where: "in_shapes[#{idx}]")
          end

          validate_dimensions!(@out_shape, where: "out_shape")

          unless [nil, :zip, :product].include?(@join_policy)
            raise SignatureError, "join_policy must be nil, :zip, or :product; got #{@join_policy.inspect}"
          end

          # Validate NEP 20 constraints
          validate_nep20_constraints!
        end

        def validate_dimensions!(dims, where: "shape")
          unless dims.is_a?(Array) && dims.all? { |d| d.is_a?(Dimension) }
            raise SignatureError, "#{where}: must be an array of Dimension objects, got: #{dims.inspect}"
          end

          # Check for duplicate dimension names within a single argument
          names = dims.map(&:name)
          duplicates = names.group_by { |n| n }.select { |_, v| v.size > 1 }.keys
          raise SignatureError, "#{where}: duplicate dimension names #{duplicates.inspect}" unless duplicates.empty?

          true
        end

        def validate_nep20_constraints!
          # Broadcastable dimensions should only appear in inputs, not outputs
          @out_shape.each do |dim|
            raise SignatureError, "output dimension #{dim} cannot be broadcastable" if dim.broadcastable?
          end

          # Fixed-size dimensions in outputs must match corresponding input dimensions
          all_input_dims = @in_shapes.flatten
          @out_shape.each do |out_dim|
            next unless out_dim.fixed_size?

            matching_inputs = all_input_dims.select { |in_dim| in_dim.name == out_dim.name }
            matching_inputs.each do |in_dim|
              if in_dim.fixed_size? && in_dim.size != out_dim.size
                raise SignatureError, "fixed-size dimension #{out_dim.name} has inconsistent sizes: #{in_dim.size} vs #{out_dim.size}"
              end
            end
          end
        end

        def deep_dup(arr) = arr.map { |x| x.is_a?(Array) ? x.dup : x }
      end
    end
  end
end
