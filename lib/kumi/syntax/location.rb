module Kumi
  module Syntax
    class Location < Struct.new(:file, :line, :column, keyword_init: true)
      def to_s
        "#{file} line=#{line} column=#{column}"
      end
    end
  end
end
