# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        # RESPONSIBILITY: Build definitions index and detect duplicate names
        # DEPENDENCIES: None (first pass in pipeline)
        # PRODUCES: :declarations - Hash mapping names to declaration nodes
        #            - annotates hints to declarations (e.g. inlining)
        # INTERFACE: new(schema, state).run(errors)
        class NameIndexer < PassBase
          def run(errors)
            definitions = {}
            hints = {}

            each_decl do |decl|
              report_error(errors, "duplicated definition `#{decl.name}`", location: decl.loc) if definitions.key?(decl.name)
              definitions[decl.name] = decl
              hints[decl.name] = decl.hints
            end

            state.with(:declarations, definitions.freeze).with(:hints, hints)
          end
        end
      end
    end
  end
end
