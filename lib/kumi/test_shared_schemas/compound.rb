# frozen_string_literal: true

module Kumi
  module TestSharedSchemas
    module Compound
      extend Kumi::Schema

      schema do
        input do
          decimal :principal
          decimal :rate
          integer :years
        end

        value :annual_interest, input.principal * input.rate
        value :total_interest, annual_interest * input.years
        value :final_amount, input.principal + total_interest
      end
    end
  end
end
