# frozen_string_literal: true

module Kumi
  module TestSharedSchemas
    module Price
      extend Kumi::Schema

      schema do
        input do
          decimal :base_price
          decimal :discount_rate
        end

        value :discounted, input.base_price * (1.0 - input.discount_rate)
        value :discount_amount, input.base_price * input.discount_rate
      end
    end
  end
end
