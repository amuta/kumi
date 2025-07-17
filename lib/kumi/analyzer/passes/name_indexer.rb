# frozen_string_literal: true

module Kumi
  module Analyzer
    module Passes
      # RESPONSIBILITY: Build definitions index and detect duplicate names
      # DEPENDENCIES: None (first pass in pipeline)
      # PRODUCES: :definitions - Hash mapping names to declaration nodes
      # INTERFACE: new(schema, state).run(errors)
      class NameIndexer < PassBase
        def run(errors)
          definitions = {}
          
          each_decl do |decl|
            if definitions.key?(decl.name)
              add_error(errors, decl.loc, "duplicated definition `#{decl.name}`")
            end
            definitions[decl.name] = decl
          end
          
          set_state(:definitions, definitions)
        end
      end
    end
  end
end
