# lib/kumi/core/lir/structs/literal.rb
module Kumi
  module Core
    module LIR
      module Structs
        Literal = Struct.new(:value, :dtype, keyword_init: true) do
          # include Typed
          def value? = true
          def to_h = { value: value, dtype: dtype }
        end
      end
    end
  end
end
