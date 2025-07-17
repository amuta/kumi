# frozen_string_literal: true

# RESPONSIBILITY
#   Build :definitions and detect duplicates.
# INTERFACE
#   new(schema, state).run(errors)
module Kumi
  module Analyzer
    module Passes
      class NameIndexer < Visitor
        def initialize(schema, state)
          super()
          @schema = schema
          @state  = state # shared accumulator
        end

        def run(errors)
          definitions = {}
          each_decl do |decl|
            errors << [decl.loc, "duplicated definition `#{decl.name}`"] if definitions.key?(decl.name)
            definitions[decl.name] = decl
          end
          @state[:definitions] = definitions
        end

        private

        def each_decl(&block)
          @schema.attributes.each(&block)
          @schema.traits.each(&block)
        end
      end
    end
  end
end
