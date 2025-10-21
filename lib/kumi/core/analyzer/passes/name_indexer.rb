# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        # RESPONSIBILITY: Build definitions index and detect duplicate names
        # DEPENDENCIES: None (first pass in pipeline)
        # PRODUCES: :declarations - Hash mapping names to declaration nodes
        #            - annotates hints to declarations (e.g. inlining)
        #           :imported_declarations - Hash of lazy import references
        # INTERFACE: new(schema, state).run(errors)
        class NameIndexer < PassBase
          def run(errors)
            definitions = {}
            imported_declarations = {}
            hints = {}

            # Phase 1: Register imports as lazy references
            schema.imports.each do |import_decl|
              import_decl.names.each do |name|
                imported_declarations[name] = {
                  type: :import,
                  from_module: import_decl.module_ref,
                  loc: import_decl.loc
                }
              end
            end

            # Phase 2: Index local declarations
            each_decl do |decl|
              if definitions.key?(decl.name) || imported_declarations.key?(decl.name)
                report_error(errors, "duplicated definition `#{decl.name}`", location: decl.loc)
              end
              definitions[decl.name] = decl
              hints[decl.name] = decl.hints
            end

            state.with(:declarations, definitions.freeze)
                 .with(:imported_declarations, imported_declarations.freeze)
                 .with(:hints, hints)
          end
        end
      end
    end
  end
end
