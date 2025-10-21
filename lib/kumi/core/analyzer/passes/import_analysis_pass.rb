# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        # RESPONSIBILITY: Load and analyze source schemas for imports
        # DEPENDENCIES: :imported_declarations from NameIndexer
        # PRODUCES: :imported_schemas - Fully analyzed source schema information with rich data:
        #           - decl: The declaration AST node
        #           - source_module: The module reference
        #           - analyzed_state: Full analyzer state of source schema (types, dependencies, etc.)
        # INTERFACE: new(schema, state).run(errors)
        class ImportAnalysisPass < PassBase
          def run(errors)
            imported_decls = get_state(:imported_declarations)
            imported_schemas = {}

            imported_decls.each do |name, meta|
              source_module = meta[:from_module]

              begin
                # Load source schema - should be a fully analyzed schema
                source_schema = source_module.kumi_schema_instance
                unless source_schema
                  raise KeyError, "#{source_module} is not a Kumi schema"
                end

                # Find declaration in source AST
                source_decl = source_schema.root.values.find { |v| v.name == name } ||
                              source_schema.root.traits.find { |t| t.name == name }

                unless source_decl
                  report_error(errors,
                    "imported definition `#{name}` not found in #{source_module}",
                    location: meta[:loc])
                  next
                end

                # Cache source info with rich analyzed state
                # The source_schema should have analyzed_state available with:
                # - input_metadata: Input field types and shapes
                # - analyzed_declarations: Fully analyzed declaration info
                # - dependencies: Declaration dependencies
                # - And all other analysis data
                imported_schemas[name] = {
                  decl: source_decl,
                  source_module: source_module,
                  source_root: source_schema.root,
                  analyzed_state: source_schema.analyzed_state,
                  input_metadata: source_schema.input_metadata
                }
              rescue => e
                report_error(errors,
                  "failed to load import `#{name}` from #{source_module}: #{e.message}",
                  location: meta[:loc])
              end
            end

            state.with(:imported_schemas, imported_schemas.freeze)
          end
        end
      end
    end
  end
end
