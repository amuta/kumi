# frozen_string_literal: true

module Kumi
  module Analyzer
    module Passes
      # RESPONSIBILITY: Collect field metadata from input declarations and validate consistency
      # DEPENDENCIES: :definitions
      # PRODUCES: :input_meta - Hash mapping field names to {type:, domain:} metadata
      # INTERFACE: new(schema, state).run(errors)
      class InputCollector < PassBase

        def run(errors)
          input_meta = {}

          schema.inputs.each do |field_decl|
            unless field_decl.is_a?(Kumi::Syntax::InputDeclaration)
              report_error(errors, "Expected InputDeclaration node, got #{field_decl.class}", location: field_decl.loc)
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

              # Validate domain type if provided
              validate_domain_type(field_decl, errors) if field_decl.domain

              # Merge metadata (later declarations override nil values)
              input_meta[name] = {
                type: field_decl.type || existing[:type],
                domain: field_decl.domain || existing[:domain]
              }
            else
              validate_domain_type(field_decl, errors) if field_decl.domain
              input_meta[name] = {
                type: field_decl.type,
                domain: field_decl.domain
              }
            end
          end

          state.with(:input_meta, input_meta.freeze)
        end

        private

        def validate_domain_type(field_decl, errors)
          domain = field_decl.domain
          return if valid_domain_type?(domain)

          report_error(errors,
                       "Field :#{field_decl.name} has invalid domain constraint: #{domain.inspect}. Domain must be a Range, Array, or Proc",
                       location: field_decl.loc)
        end

        def valid_domain_type?(domain)
          domain.is_a?(Range) || domain.is_a?(Array) || domain.is_a?(Proc)
        end
      end
    end
  end
end
