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

        def each_decl(&b)
          @schema.attributes.each(&b)
          @schema.traits.each(&b)
        end
      end
    end
  end
end
