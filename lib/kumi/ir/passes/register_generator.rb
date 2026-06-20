# frozen_string_literal: true

module Kumi
  module IR
    module Passes
      # Hands out fresh `:vN` register names for a pass that mints new
      # instructions, seeded past the highest existing `vN` in the function so a
      # generated register never collides with one the lowerer already used.
      class RegisterGenerator
        def initialize(function)
          @counter = highest_existing(function)
        end

        def next
          @counter += 1
          :"v#{@counter}"
        end

        private

        def highest_existing(function)
          regs = function.blocks.flat_map(&:instructions).filter_map(&:result)
          nums = regs.filter_map do |reg|
            match = reg.to_s.match(/^v(\d+)$/)
            match && match[1].to_i
          end
          nums.max || 0
        end
      end
    end
  end
end
