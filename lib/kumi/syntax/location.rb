module Kumi
  module Syntax
    Location = Struct.new(:file, :line, :column, keyword_init: true)
  end
end
