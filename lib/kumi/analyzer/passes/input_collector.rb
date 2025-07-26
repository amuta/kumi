# frozen_string_literal: true

module Kumi
  module Analyzer
    module Passes
      # RESPONSIBILITY: Collect field metadata from input declarations and validate consistency
      # DEPENDENCIES: :definitions
      # PRODUCES: :input_meta - Hash mapping field names to {type:, domain:} metadata
      # INTERFACE: new(schema, state).run(errors)
      class InputCollector < PassBase
        include Syntax::TerminalExpressions

        def run(errors)
          input_meta = {}

          schema.inputs.each do |field_decl|
            unless field_decl.is_a?(FieldDecl)
              report_error(errors, "Expected FieldDecl node, got #{field_decl.class}", location: field_decl.loc)
              next
            end

            name = field_decl.name
            existing = input_meta[name]

            if existing
              # Check for compatibility
              if existing[:type] != field_decl.type && field_decl.type && existing[:type]
                report_error(errors,
                             "Field :#{name} declared with conflicting types: #{existing[:type]} vs #{field_decl.type}",
                             location: field_decl.loc)
              end

              if existing[:domain] != field_decl.domain && field_decl.domain && existing[:domain]
                report_error(errors,
                             "Field :#{name} declared with conflicting domains: #{existing[:domain].inspect} vs #{field_decl.domain.inspect}",
                             location: field_decl.loc)
              end

              # Merge metadata (later declarations override nil values)
              input_meta[name] = {
                type: field_decl.type || existing[:type],
                domain: field_decl.domain || existing[:domain]
              }
            else
              input_meta[name] = {
                type: field_decl.type,
                domain: field_decl.domain
              }
            end
          end

          state.with(:input_meta, input_meta.freeze)
        end
      end
    end
  end
end
