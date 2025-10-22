# frozen_string_literal: true

module Kumi
  module TestSharedSchemas
    module Tax
      extend Kumi::Schema

      schema do
        input do
          decimal :amount
        end

        value :tax, input.amount * 0.15
        value :total, input.amount + tax
      end
    end
  end
end
