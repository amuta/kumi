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
                source_module = resolve_source_module(source_module_ref)
              rescue NameError => e
                report_error(
                  errors,
                  "cannot import `#{name}`: module #{source_module_ref.inspect} not found (#{e.message})",
                  location: meta[:loc]
                )
                next
              end

              begin
                syntax_tree = source_module.__kumi_syntax_tree__
              rescue NoMethodError
                report_error(
                  errors,
                  "cannot import `#{name}` from #{qualified_ref(source_module_ref, source_module)}: not a Kumi schema (missing __kumi_syntax_tree__)",
                  location: meta[:loc]
                )
                next
              end

              source_decl = syntax_tree.values.find { |v| v.name == name } ||
                            syntax_tree.traits.find { |t| t.name == name }

              unless source_decl
                available = (syntax_tree.values.map(&:name) + syntax_tree.traits.map(&:name)).sort
                msg = "imported declaration `#{name}` not found in #{qualified_ref(source_module_ref, source_module)}"
                msg += "\navailable declarations: #{available.join(', ')}" if available.any?
                report_error(errors, msg, location: meta[:loc])
                next
              end

              begin
                analyzed_state = Kumi::Analyzer.analyze!(syntax_tree).state
              rescue => e
                report_error(
                  errors,
                  "failed to analyze imported schema from #{qualified_ref(source_module_ref, source_module)}: #{e.class}: #{e.message}",
                  location: meta[:loc]
                )
                next
              end

              imported_schemas[name] = {
                decl: source_decl,
                source_module: source_module,
                source_root: syntax_tree,
                analyzed_state: analyzed_state,
                input_metadata: analyzed_state[:input_metadata] || {}
              }
            end

            state.with(:imported_schemas, imported_schemas.freeze)
          end

          private

          def resolve_source_module(source_module_ref)
            if source_module_ref.is_a?(String)
              Object.const_get(source_module_ref)
            else
              source_module_ref
            end
          end

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
