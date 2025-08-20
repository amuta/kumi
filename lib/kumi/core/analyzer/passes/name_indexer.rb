# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        # RESPONSIBILITY: Build definitions index and detect duplicate names
        # DEPENDENCIES: None (first pass in pipeline)
        # PRODUCES:
        #   :declarations - Hash mapping names to declaration nodes
        #   :node_index - Hash mapping InputElementReferences to
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

          private

          # creates
          # def
        end
      end
    end
  end
end
