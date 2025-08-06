# frozen_string_literal: true

module Kumi
  module Core
    # Generates Three-Address Code (TAC) IR from analyzer results
    # Flattens complex expressions into simple linear operations
    class TACIRGenerator
      def initialize(syntax_tree, analysis_result)
        @syntax_tree = syntax_tree
        @analysis = analysis_result
        @state = analysis_result.state
        @temp_counter = 0
        @tac_instructions = []
      end

      def generate
        {
          # Linear sequence of TAC instructions (no accessors - let IR compiler handle that)
          instructions: generate_tac_instructions,
          
          # Dependencies preserved for debugging
          dependencies: @state[:dependencies] || {}
        }
      end

      private

      def generate_tac_instructions
        instructions = []
        
        # Process declarations in topological order
        @analysis.topo_order.each do |name|
          declaration = find_declaration(name)
          next unless declaration
          
          # Generate TAC instruction(s) for this declaration
          tac_instructions = generate_declaration_tac(name, declaration)
          instructions.concat(tac_instructions)
        end
        
        instructions
      end

      def generate_declaration_tac(name, declaration)
        # Get broadcast detector metadata
        detector_metadata = @state[:detector_metadata] || {}
        decl_meta = detector_metadata[name] || {}
        
        case decl_meta[:operation_type]
        when :element_wise
          generate_element_wise_tac(name, declaration, decl_meta)
        when :scalar
          generate_scalar_tac(name, declaration)
        when :reduction
          generate_reduction_tac(name, declaration, decl_meta)
        when :array_reference
          generate_array_reference_tac(name, declaration, decl_meta)
        else
          # Fallback to simple assignment
          [create_tac_instruction(name, :assign, [declaration.expression])]
        end
      end

      def generate_element_wise_tac(name, declaration, metadata)
        # For vectorized operations, we need to flatten any nested expressions
        operands = metadata[:operands] || []
        
        # Check if any operands need flattening (contain nested CallExpressions)
        flattened_operands = operands.map do |operand_meta|
          if operand_meta[:source][:kind] == :computed_result
            # This operand is from a nested expression - generate temp for it
            temp_name = generate_temp_name
            nested_metadata = operand_meta[:source][:operation_metadata]
            
            # Generate TAC instruction for the nested operation
            temp_instruction = create_tac_instruction(
              temp_name,
              :element_wise,
              nested_metadata[:operands],
              nested_metadata
            )
            @tac_instructions << temp_instruction
            
            # Replace with reference to temp
            {
              type: operand_meta[:type],
              source: {
                kind: :declaration,
                name: temp_name
              }
            }
          else
            # Use operand as-is
            operand_meta
          end
        end
        
        # Extract function name from original AST expression
        enhanced_metadata = metadata.dup
        if declaration.expression.is_a?(Kumi::Syntax::CallExpression)
          enhanced_metadata[:function] = declaration.expression.fn_name
        end
        
        # Create the main TAC instruction
        main_instruction = create_tac_instruction(
          name,
          :element_wise,
          flattened_operands,
          enhanced_metadata
        )
        
        # Return all instructions generated (temps + main)
        temp_instructions = @tac_instructions.dup
        @tac_instructions.clear
        temp_instructions + [main_instruction]
      end

      def generate_scalar_tac(name, declaration)
        # Scalar operations are always simple
        [create_tac_instruction(name, :scalar, [declaration.expression])]
      end

      def generate_reduction_tac(name, declaration, metadata)
        [create_tac_instruction(name, :reduction, [declaration.expression], metadata)]
      end

      def generate_array_reference_tac(name, declaration, metadata)
        [create_tac_instruction(name, :array_reference, [declaration.expression], metadata)]
      end

      def create_tac_instruction(name, operation_type, operands, metadata = {})
        # TAC generates call_expression format, with broadcast metadata when available
        compilation = {
          type: :call_expression,
          function: metadata[:function] || extract_function_from_expression(operands.first),
          operands: convert_operands_to_tac(operands)
        }
        
        # Include broadcast metadata for array operations
        if metadata[:strategy] && metadata[:registry_call_info]
          compilation[:broadcast_strategy] = metadata[:strategy]
          compilation[:registry_function] = metadata.dig(:registry_call_info, :function_name)
        end
        
        {
          name: name,
          compilation: compilation,
          temp: name.to_s.start_with?('__temp_')
        }
      end
      
      def extract_function_from_expression(expr_or_operand)
        # Extract function name from AST expression or operand metadata
        case expr_or_operand
        when Kumi::Syntax::CallExpression
          expr_or_operand.fn_name
        when Hash
          # If it's operand metadata, we need the original expression
          nil
        else
          :add  # fallback
        end
      end

      def convert_operands_to_tac(operands)
        # Convert operands to simple TAC format
        operands.map do |operand|
          case operand
          when Hash
            # Already processed operand metadata
            convert_operand_metadata_to_tac(operand)
          else
            # Raw AST expression - convert to TAC operand
            convert_ast_operand_to_tac(operand)
          end
        end
      end

      def convert_operand_metadata_to_tac(operand_meta)
        source = operand_meta[:source]
        
        case source[:kind]
        when :input_element
          {
            type: :input_element_reference,
            path: source[:path]
          }
        when :input_field
          {
            type: :input_reference,
            name: source[:name]
          }
        when :declaration
          {
            type: :declaration_reference,
            name: source[:name]
          }
        when :literal
          {
            type: :literal,
            value: source[:value]
          }
        else
          raise "Unsupported TAC operand source: #{source[:kind]}"
        end
      end

      def convert_ast_operand_to_tac(operand)
        case operand
        when Kumi::Syntax::InputElementReference
          {
            type: :input_element_reference,
            path: operand.path
          }
        when Kumi::Syntax::InputReference
          {
            type: :input_reference,
            name: operand.name
          }
        when Kumi::Syntax::DeclarationReference
          {
            type: :declaration_reference,
            name: operand.name
          }
        when Kumi::Syntax::Literal
          {
            type: :literal,
            value: operand.value
          }
        else
          raise "Unsupported AST operand type: #{operand.class}"
        end
      end

      def generate_temp_name
        @temp_counter += 1
        "__temp_#{@temp_counter}".to_sym
      end

      def find_declaration(name)
        (@syntax_tree.attributes + @syntax_tree.traits).find { |decl| decl.name == name }
      end
    end
  end
end