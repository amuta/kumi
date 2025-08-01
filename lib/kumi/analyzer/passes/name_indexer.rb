# frozen_string_literal: true

module Kumi
  module Analyzer
    module Passes
      # RESPONSIBILITY: Build definitions index and detect duplicate names
      # DEPENDENCIES: None (first pass in pipeline)
      # PRODUCES: :declarations - Hash mapping names to declaration nodes
      # INTERFACE: new(schema, state).run(errors)
      class NameIndexer < PassBase
        def run(errors)
          definitions = {}

          each_decl do |decl|
            report_error(errors, "duplicated definition `#{decl.name}`", location: decl.loc) if definitions.key?(decl.name)
            definitions[decl.name] = decl
          end

          state.with(:declarations, definitions.freeze)
        end
      end
    end
  end
end
