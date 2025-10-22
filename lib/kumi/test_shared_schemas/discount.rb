# frozen_string_literal: true

module Kumi
  module TestSharedSchemas
    module Discount
      extend Kumi::Schema

      schema do
        input do
          decimal :price
          decimal :rate
        end

        value :discounted, input.price * (1.0 - input.rate)
        value :savings, input.price * input.rate
      end
    end
  end
end
