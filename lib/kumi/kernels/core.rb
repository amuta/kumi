# frozen_string_literal: true

module Kumi
  module Kernels
    module Core
      def self.add(left, right)
        left + right
      end

      def self.sub(left, right)
        left - right
      end

      def self.mul(left, right)
        left * right
      end

      def self.pow(base, exponent)
        base ** exponent
      end

      def self.eq(left, right)
        left == right
      end

      def self.gt(left, right)
        left > right
      end

      def self.gte(left, right)
        left >= right
      end

      def self.and(left, right)
        left && right
      end

      def self.length(collection)
        collection.size
      end

      def self.select(condition, true_val, false_val)
        condition ? true_val : false_val
      end
    end
  end
end