# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        class InputFormSchemaPass < PassBase
          def run(_errors)
            input_metadata = get_state(:input_metadata)
            return state unless input_metadata

            form_schema = build_form_schema(input_metadata)
            state.with(:input_form_schema, form_schema.freeze)
          end

          private

          def build_form_schema(metadata)
            metadata.transform_values { |node| node_to_form_field(node) }
          end

          def node_to_form_field(node)
            case node.container
            when :scalar
              { type: node.type }
            when :array
              element = node.children.values.first
              {
                type: :array,
                element: element ? node_to_form_field(element) : nil
              }
            when :hash
              {
                type: :object,
                fields: node.children.transform_values { |child| node_to_form_field(child) }
              }
            end
          end
        end
      end
    end
  end
end
