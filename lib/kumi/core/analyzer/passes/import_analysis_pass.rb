# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        class ImportAnalysisPass < PassBase
          def run(errors)
            imported_decls = get_state(:imported_declarations)
            imported_schemas = {}

            imported_decls.each do |name, meta|
              source_module_ref = meta[:from_module]

              begin
                source_module =
                  if source_module_ref.is_a?(String)
                    Object.const_get(source_module_ref)
                  else
                    source_module_ref
                  end

                syntax_tree = source_module.__kumi_syntax_tree__

                source_decl = syntax_tree.values.find { |v| v.name == name } ||
                              syntax_tree.traits.find { |t| t.name == name }

                unless source_decl
                  report_error(
                    errors,
                    "imported definition `#{name}` not found in #{qualified_ref(source_module_ref, source_module)}",
                    location: meta[:loc]
                  )
                  next
                end

                analyzed_state = Kumi::Analyzer.analyze!(syntax_tree).state

                imported_schemas[name] = {
                  decl: source_decl,
                  source_module: source_module,
                  source_root: syntax_tree,
                  analyzed_state: analyzed_state,
                  input_metadata: analyzed_state[:input_metadata] || {}
                }
              rescue => e
                report_error(
                  errors,
                  "failed to load import `#{name}` from #{qualified_ref(source_module_ref)}: #{e.class}: #{e.message}",
                  location: meta[:loc]
                )
              end
            end

            state.with(:imported_schemas, imported_schemas.freeze)
          end

          private

          def qualified_ref(ref, mod = nil)
            return mod if mod
            return ref if ref
            "(unknown)"
          end
        end
      end
    end
  end
end
