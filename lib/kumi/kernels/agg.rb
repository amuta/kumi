# frozen_string_literal: true

module Kumi
  module Kernels
    module Agg
      def self.zero(dtype)
        case dtype
        when :integer, :float then 0
        when :boolean         then false   # for any
        else 0                   # adjust as you add dtypes
        end
      end

      def self.sum(acc, val) 
        acc + val 
      end
      
      def self.id(acc) 
        acc 
      end
    end
  end
end