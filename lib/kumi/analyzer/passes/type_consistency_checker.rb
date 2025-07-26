# frozen_string_literal: true

module Kumi
  module Analyzer
    module Passes
      # RESPONSIBILITY: Validate consistency between declared and inferred types
      # DEPENDENCIES: :input_meta from InputCollector, :decl_types from TypeInferencer
      # PRODUCES: None (validation only)
      # INTERFACE: new(schema, state).run(errors)
      class TypeConsistencyChecker < PassBase
        def run(errors)
          input_meta = get_state(:input_meta, required: false) || {}

          # First, validate that all declared types are valid
          validate_declared_types(input_meta, errors)

          # Then check basic consistency (placeholder for now)
          # In a full implementation, this would do sophisticated usage analysis
          state
        end

        private

        def validate_declared_types(input_meta, errors)
          input_meta.each do |field_name, meta|
            declared_type = meta[:type]
            next unless declared_type # Skip fields without declared types
            next if Kumi::Types.valid_type?(declared_type)

            # Find the input field declaration for proper location information
            field_decl = find_input_field_declaration(field_name)
            location = field_decl&.loc

            add_error(errors, location, "Invalid type declaration for field :#{field_name}: #{declared_type.inspect}")
          end
        end

        def find_input_field_declaration(field_name)
          return nil unless schema

          schema.inputs.find { |input_decl| input_decl.name == field_name }
        end
      end
    end
  end
end
