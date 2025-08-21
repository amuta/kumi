# frozen_string_literal: true

module Kumi
  module Support
    module Diff
      module_function
      
      def unified(a_str, b_str)
        a = a_str.lines
        b = b_str.lines
        out = []
        max = [a.size, b.size].max
        (0...max).each do |i|
          next if a[i] == b[i]
          out << format("%4d- %s", i + 1, a[i] || "")
          out << format("%4d+ %s", i + 1, b[i] || "")
        end
        out.join
      end
    end
  end
end