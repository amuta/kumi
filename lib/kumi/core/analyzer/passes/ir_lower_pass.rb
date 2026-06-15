# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        class IRLowerPass < PassBase
          class << self
            attr_reader :from_key, :to_key

            def lowers(from:, to:)
              @from_key = from
              @to_key = to
              optional_reads from
              writes to
            end
          end

          def run(_errors)
            source = state[self.class.from_key]
            return state unless source

            state.with(self.class.to_key, lower(source).freeze)
          end

          private

          def lower(source)
            raise NotImplementedError, "#{self.class.name} must implement #lower"
          end
        end
      end
    end
  end
end
