# frozen_string_literal: true

module Kumi
  module Analyzer
    module Passes
      # RESPONSIBILITY: Build definitions index and detect duplicate names
      # DEPENDENCIES: None (first pass in pipeline)
      # PRODUCES: :definitions - Hash mapping names to declaration nodes
      #           :input_keys - Set of input names
      # INTERFACE: new(schema, state).run(errors)
      class NameIndexer < PassBase
        def run(errors)
          definitions = {}

          each_decl do |decl|
            add_error(errors, decl.loc, "duplicated definition `#{decl.name}`") if definitions.key?(decl.name)
            definitions[decl.name] = decl
          end

          set_state(:definitions, definitions.freeze)
        end
      end
    end
  end
end
