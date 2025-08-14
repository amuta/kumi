# frozen_string_literal: true

require_relative "dimension"
require_relative "signature"

module Kumi
  module Core
    module Functions
      # Parses NEP 20 conformant signature strings like:
      #  "(),()->()"                    # scalar operations
      #  "(i),(i)->(i)"                 # vector operations
      #  "(i),(j)->(i,j)@product"       # matrix operations with join policy
      #  "(i,j)->(i)"                   # reduction of :j
      #  "(3),(3)->(3)"                 # fixed-size 3-vectors (cross product)
      #  "(i?),(i?)->(i?)"               # flexible dimensions
      #  "(i|1),(i|1)->()"               # broadcastable dimensions
      #  "(m?,n),(n,p?)->(m?,p?)"        # matmul signature
      class SignatureParser
        class << self
          def parse(str)
            raise SignatureParseError, "empty signature" if str.nil? || str.strip.empty?
            lhs, rhs = str.split("->", 2)&.map!(&:strip)
            raise SignatureParseError, "signature must contain '->': #{str.inspect}" unless rhs

            out_spec, policy = rhs.split("@", 2)&.map!(&:strip)
            in_shapes = parse_many(lhs)
            out_shape = parse_axes(out_spec)
            join_policy = policy&.to_sym

            Signature.new(in_shapes: in_shapes, out_shape: out_shape, join_policy: join_policy, raw: str)
          rescue SignatureError => e
            raise
          rescue StandardError => e
            raise SignatureParseError, "invalid signature #{str.inspect}: #{e.message}"
          end

          private

          def parse_many(lhs)
            # Handle zero arguments case
            return [] if lhs.strip.empty?

            # split by commas that are *between* groups, not inside them  
            # simpler approach: split by '),', re-add ')' where needed
            tokens = lhs.split("),").map { |t| t.strip.end_with?(")") ? t.strip : "#{t.strip})" }
            tokens.map { |tok| parse_axes(tok) }
          end

          def parse_axes(spec)
            spec = spec.strip
            raise SignatureParseError, "missing parentheses in #{spec.inspect}" unless spec.start_with?("(") && spec.end_with?(")")

            inner = spec[1..-2].strip
            return [] if inner.empty?

            inner.split(",").map { |dim_str| parse_dimension(dim_str.strip) }
          end

          # Parse a single dimension with NEP 20 modifiers
          # Examples: "i", "3", "n?", "i|1"
          def parse_dimension(dim_str)
            return Dimension.new(:empty) if dim_str.empty?

            # Extract modifiers
            flexible = dim_str.end_with?("?")
            dim_str = dim_str.chomp("?") if flexible

            broadcastable = dim_str.end_with?("|1")
            dim_str = dim_str.chomp("|1") if broadcastable

            # Parse name (symbol or integer)
            name = if dim_str.match?(/^\d+$/)
                     dim_str.to_i
                   else
                     dim_str.to_sym
                   end

            Dimension.new(name, flexible: flexible, broadcastable: broadcastable)
          rescue StandardError => e
            raise SignatureParseError, "invalid dimension #{dim_str.inspect}: #{e.message}"
          end
        end
      end
    end
  end
end
