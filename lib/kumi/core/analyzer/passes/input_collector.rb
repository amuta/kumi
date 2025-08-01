# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        # RESPONSIBILITY: Collect field metadata from input declarations and validate consistency
        # DEPENDENCIES: :definitions
        # PRODUCES: :inputs - Hash mapping field names to {type:, domain:} metadata
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
                # Check for compatibility and merge
                merged_meta = merge_field_metadata(existing, field_decl, errors)
                input_meta[name] = merged_meta if merged_meta
              else
                # New field - collect its metadata
                input_meta[name] = collect_field_metadata(field_decl, errors)
              end
            end

            state.with(:inputs, freeze_nested_hash(input_meta))
          end

          private

          def collect_field_metadata(field_decl, errors)
            validate_domain_type(field_decl, errors) if field_decl.domain

            metadata = {
              type: field_decl.type,
              domain: field_decl.domain
            }

            # Process children if present
            if field_decl.children && !field_decl.children.empty?
              children_meta = {}
              field_decl.children.each do |child_decl|
                unless child_decl.is_a?(Kumi::Syntax::InputDeclaration)
                  report_error(errors, "Expected InputDeclaration node in children, got #{child_decl.class}", location: child_decl.loc)
                  next
                end
                children_meta[child_decl.name] = collect_field_metadata(child_decl, errors)
              end
              metadata[:children] = children_meta
            end

            metadata
          end

          def merge_field_metadata(existing, field_decl, errors)
            name = field_decl.name

            # Check for type compatibility
            if existing[:type] != field_decl.type && field_decl.type && existing[:type]
              report_error(errors,
                           "Field :#{name} declared with conflicting types: #{existing[:type]} vs #{field_decl.type}",
                           location: field_decl.loc)
            end

            # Check for domain compatibility
            if existing[:domain] != field_decl.domain && field_decl.domain && existing[:domain]
              report_error(errors,
                           "Field :#{name} declared with conflicting domains: #{existing[:domain].inspect} vs #{field_decl.domain.inspect}",
                           location: field_decl.loc)
            end

            # Validate domain type if provided
            validate_domain_type(field_decl, errors) if field_decl.domain

            # Merge metadata (later declarations override nil values)
            merged = {
              type: field_decl.type || existing[:type],
              domain: field_decl.domain || existing[:domain]
            }

            # Merge children if present
            if field_decl.children && !field_decl.children.empty?
              existing_children = existing[:children] || {}
              new_children = {}

              field_decl.children.each do |child_decl|
                unless child_decl.is_a?(Kumi::Syntax::InputDeclaration)
                  report_error(errors, "Expected InputDeclaration node in children, got #{child_decl.class}", location: child_decl.loc)
                  next
                end

                child_name = child_decl.name
                new_children[child_name] = if existing_children[child_name]
                                             merge_field_metadata(existing_children[child_name], child_decl, errors)
                                           else
                                             collect_field_metadata(child_decl, errors)
                                           end
              end

              merged[:children] = new_children
            elsif existing[:children]
              merged[:children] = existing[:children]
            end

            merged
          end

          def freeze_nested_hash(hash)
            hash.each_value do |value|
              freeze_nested_hash(value) if value.is_a?(Hash)
            end
            hash.freeze
          end

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
end
