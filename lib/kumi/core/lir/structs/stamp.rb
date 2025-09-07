# lib/kumi/core/lir/structs/stamp.rb
module Kumi
  module Core
    module LIR
      module Structs
        Stamp = Struct.new(:dtype, keyword_init: true) do
          # include Typed   # enable if you add typed.rb
          def to_h = { dtype: dtype }
        end
      end
    end
  end
end