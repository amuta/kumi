# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        class NameIndexer < PassBase
          writes :declarations, :imported_declarations, :hints

          def run(errors)
            definitions = {}
            imported_declarations = {}
            hints = {}

            # Phase 1: Register imports as lazy references
            (schema.imports || []).each do |import_decl|
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
