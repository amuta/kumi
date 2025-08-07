# frozen_string_literal: true

module Kumi
  module Core
    module IRGeneratorModules
      # Handles operand conversion between different formats
      module OperandMapper
        # Make this public so CascadeIrGenerator can use it
        def generate_operand_info(operand)
          case operand
          when Kumi::Syntax::InputReference
            {
              type: :input_reference,
              name: operand.name
            }
          when Kumi::Syntax::InputElementReference
            {
              type: :input_element_reference,
              path: operand.path,
              accessor: build_accessor_key(operand.path, :element)
            }
          when Kumi::Syntax::Literal
            {
              type: :literal,
              value: operand.value
            }
          when Kumi::Syntax::DeclarationReference
            {
              type: :declaration_reference,
              name: operand.name
            }
          when Kumi::Syntax::CallExpression
            {
              type: :call_expression,
              function: operand.fn_name,
              operands: operand.args.map { |arg| generate_operand_info(arg) }
            }
          when Kumi::Syntax::ArrayExpression
            {
              type: :array_expression,
              elements: operand.elements.map { |elem| generate_operand_info(elem) }
            }
          else
            raise "Unknown operand type: #{operand.class}"
          end
        end

        private

        def generate_element_wise_operands(detector_operands)
          # Check if we need TAC decomposition for complex expressions
          if needs_tac_decomposition?(detector_operands)
            # Decompose nested expressions into temps
            decomposed_operands = decompose_nested_operands(detector_operands, :element_wise)
            # Convert decomposed operands to IR format
            convert_detector_operands_to_ir_format(decomposed_operands)
          else
            # Convert simple operands directly
            convert_detector_operands_to_ir_format(detector_operands)
          end
        end

        def convert_detector_operands_to_ir_format(detector_operands)
          # Convert broadcast detector operand metadata to IR operand format
          detector_operands.map do |operand_meta|
            case operand_meta[:type]
            when :source
              source = operand_meta[:source]
              case source[:kind]
              when :input_field
                {
                  type: :input_reference,
                  name: source[:name],
                  accessor: "#{source[:name]}:structure"
                }
              when :input_element
                {
                  type: :input_element_reference,
                  path: source[:path],
                  accessor: "#{source[:path].join('.')}:element"
                }
              when :declaration
                {
                  type: :declaration_reference,
                  name: source[:name]
                }
              else
                raise "Unsupported source kind after TAC decomposition: #{source[:kind]} - #{source.inspect}"
              end
            when :scalar
              source = operand_meta[:source]
              case source[:kind]
              when :literal
                {
                  type: :literal,
                  value: source[:value]
                }
              when :declaration
                {
                  type: :declaration_reference,
                  name: source[:name]
                }
              when :input_field
                {
                  type: :input_reference,
                  name: source[:name],
                  accessor: "#{source[:name]}:structure"
                }
              else
                raise "Unsupported scalar source kind: #{source[:kind]}"
              end
            else
              raise "Unsupported element_wise operand type: #{operand_meta[:type]}"
            end
          end
        end
      end
    end
  end
end