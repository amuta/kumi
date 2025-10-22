# frozen_string_literal: true

module Kumi
  module TestSharedSchemas
    module Subtotal
      extend Kumi::Schema

      schema do
        input do
          array :items do
            hash :item do
              integer :quantity
              integer :unit_price
            end
          end
        end

        value :subtotal, fn(:sum, input.items.item.quantity * input.items.item.unit_price)
      end
    end
  end
end
