# lib/kumi/core/lir/ids.rb
# Ids generates deterministic temp and loop ids. Each compilation context gets its own instance.
module Kumi
  module Core
    module LIR
      class Ids
        def initialize
          reset!
        end

        def reset!
          @t = 0
          @l = 0
        end

        def generate_temp(prefix: :t)
          @t += 1
          :"#{prefix}#{@t}"
        end

        def generate_loop_id
          @l += 1
          :"L#{@l}"
        end
      end
    end
  end
end