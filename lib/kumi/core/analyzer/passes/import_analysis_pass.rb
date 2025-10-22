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
              source_module_ref = meta[:from_module]

              begin
                # Resolve module reference (can be a Module or a string constant name)
                source_module = if source_module_ref.is_a?(String)
                                  # Text parser provides constant names as strings (e.g., "GoldenSchemas::Tax")
                                  Object.const_get(source_module_ref)
                                else
                                  # Ruby DSL provides modules directly
                                  source_module_ref
                                end

                # Get syntax tree from Kumi::Schema extended module
                syntax_tree = source_module.__kumi_syntax_tree__

                # Find declaration in source AST
                source_decl = syntax_tree.values.find { |v| v.name == name } ||
                              syntax_tree.traits.find { |t| t.name == name }

                unless source_decl
                  report_error(errors,
                    "imported definition `#{name}` not found in #{source_module}",
                    location: meta[:loc])
                  next
                end

                # Analyze the source schema to get full state
                analyzed_result = Kumi::Analyzer.analyze!(syntax_tree)
                analyzed_state = analyzed_result.state

                # Cache source info with rich analyzed state
                imported_schemas[name] = {
                  decl: source_decl,
                  source_module: source_module,
                  source_root: syntax_tree,
                  analyzed_state: analyzed_state,
                  input_metadata: analyzed_state[:input_metadata] || {}
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
