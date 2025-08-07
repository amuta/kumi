# frozen_string_literal: true

module Kumi
  module Core
    # Module for handling Three-Address Code (TAC) decomposition of complex expressions
    # Can be extended into IR generators to handle nested expressions
    module TACDecomposer
      def initialize_tac
        @temp_counter = 0
        @pending_temp_instructions = []
      end

      # Decomposes complex nested expressions into simple TAC operations
      def decompose_nested_operands(detector_operands, operation_type)
        decomposed_operands = detector_operands.map do |operand_meta|
          case operand_meta[:source][:kind]
          when :nested_call
            # Generate temp for nested expression
            decompose_nested_call(operand_meta)
          when :computed_result
            # Generate temp for complex inline expressions
            decompose_computed_result(operand_meta) 
          else
            # Use operand as-is for simple cases
            operand_meta
          end
        end

        decomposed_operands
      end

      # Flushes any pending temp instructions and returns them
      def flush_temp_instructions
        temp_instructions = @pending_temp_instructions.dup
        @pending_temp_instructions.clear
        temp_instructions
      end

      # Checks if operands contain complex expressions needing decomposition
      def needs_tac_decomposition?(detector_operands)
        return false unless detector_operands

        detector_operands.any? do |operand_meta|
          source_kind = operand_meta.dig(:source, :kind)
          source_kind == :nested_call || source_kind == :computed_result
        end
      end

      private

      def decompose_nested_call(operand_meta)
        temp_name = generate_temp_name
        nested_expr = operand_meta[:source][:expression]
        
        # Create temp instruction for the nested operation
        temp_instruction = create_temp_instruction_for_nested_call(temp_name, nested_expr)
        @pending_temp_instructions << temp_instruction
        
        # Replace operand with reference to temp
        {
          type: operand_meta[:type],
          source: {
            kind: :declaration,
            name: temp_name
          }
        }
      end

      def decompose_computed_result(operand_meta)
        temp_name = generate_temp_name
        
        # Create temp instruction for the computed result
        temp_instruction = create_temp_instruction_for_computed_result(temp_name, operand_meta)
        @pending_temp_instructions << temp_instruction
        
        # Replace operand with reference to temp
        {
          type: operand_meta[:type],
          source: {
            kind: :declaration,
            name: temp_name
          }
        }
      end

      def create_temp_instruction_for_nested_call(temp_name, nested_expr)
        # Analyze the nested expression to get metadata
        nested_metadata = analyze_nested_expression(nested_expr)
        
        {
          name: temp_name,
          type: :valuedeclaration,
          operation_type: determine_nested_operation_type(nested_expr, nested_metadata),
          data_type: infer_temp_type(nested_expr),
          compilation: create_temp_compilation(nested_expr, nested_metadata),
          temp: true
        }
      end

      def create_temp_instruction_for_computed_result(temp_name, operand_meta)
        {
          name: temp_name,
          type: :valuedeclaration,
          operation_type: :scalar, # Computed results are typically scalar
          data_type: :any, # TODO: Better type inference
          compilation: {
            type: :computed_expression,
            metadata: operand_meta
          },
          temp: true
        }
      end

      def analyze_nested_expression(nested_expr)
        case nested_expr
        when Kumi::Syntax::CallExpression
          {
            function: nested_expr.fn_name,
            operands: nested_expr.args.map { |arg| analyze_operand_for_tac(arg) }
          }
        else
          { function: :identity, operands: [] }
        end
      end

      def determine_nested_operation_type(nested_expr, metadata)
        # Check if any operands suggest element-wise processing
        if metadata[:operands].any? { |op| op[:type] == :source && op[:source][:kind] == :input_element }
          :element_wise
        else
          :scalar
        end
      end

      def infer_temp_type(nested_expr)
        # Basic type inference for temp variables
        # TODO: Integrate with main type inferencer
        case nested_expr
        when Kumi::Syntax::CallExpression
          case nested_expr.fn_name
          when :multiply, :add, :subtract, :divide
            :float
          when :>, :<, :>=, :<=, :==, :!=
            :boolean
          else
            :any
          end
        else
          :any
        end
      end

      def create_temp_compilation(nested_expr, metadata)
        case nested_expr
        when Kumi::Syntax::CallExpression
          {
            type: :element_wise_operation,
            strategy: nil,
            function: nested_expr.fn_name,
            registry_function: nil,
            operands: convert_tac_operands_to_ir_format(metadata[:operands])
          }
        else
          {
            type: :literal,
            value: nil
          }
        end
      end

      def convert_tac_operands_to_ir_format(tac_operands)
        tac_operands.map do |operand_meta|
          source = operand_meta[:source]
          
          case source[:kind]
          when :input_element
            {
              type: :input_element_reference,
              path: source[:path],
              accessor: "#{source[:path].join('.')}:element"
            }
          when :input_field
            {
              type: :input_reference,
              name: source[:name],
              accessor: "#{source[:name]}:structure"
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
      end

      def analyze_operand_for_tac(operand)
        case operand
        when Kumi::Syntax::InputElementReference
          {
            type: :source,
            source: {
              kind: :input_element,
              path: operand.path
            }
          }
        when Kumi::Syntax::InputReference
          {
            type: :source,
            source: {
              kind: :input_field,
              name: operand.name
            }
          }
        when Kumi::Syntax::DeclarationReference
          {
            type: :source,
            source: {
              kind: :declaration,
              name: operand.name
            }
          }
        when Kumi::Syntax::Literal
          {
            type: :scalar,
            source: {
              kind: :literal,
              value: operand.value
            }
          }
        when Kumi::Syntax::CallExpression
          # Nested call expression - will need further decomposition
          {
            type: :source,
            source: {
              kind: :nested_call,
              expression: operand
            }
          }
        else
          raise "Unsupported operand type for TAC: #{operand.class}"
        end
      end

      def generate_temp_name
        @temp_counter += 1
        "__temp_#{@temp_counter}".to_sym
      end
    end
  end
end