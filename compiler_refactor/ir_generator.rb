# frozen_string_literal: true

module Kumi
  module Core
    # Generates structured IR from analyzer result
    # This will become the final analyzer pass
    class IRGenerator
      def initialize(syntax_tree, analysis_result)
        @syntax_tree = syntax_tree
        @analysis = analysis_result
        @state = analysis_result.state
      end

      def generate
        {
          # Pre-computed accessors for all input paths
          accessors: generate_accessors,
          
          # Compilation instructions in evaluation order
          instructions: generate_instructions,
          
          # Dependencies preserved for debugging  
          dependencies: @state[:dependencies] || {}
        }
      end

      private

      def generate_accessors
        # Use the existing AccessorPlanner and AccessorBuilder
        input_metadata = @state[:inputs] || {}
        access_plans = Core::Compiler::AccessorPlanner.plan(input_metadata)
        built_accessors = Core::Compiler::AccessorBuilder.build(access_plans)
        
        # Return the built accessors directly - they're keyed as "path:mode"
        built_accessors
      end

      def generate_instructions
        instructions = []
        
        # Process declarations in topological order
        @analysis.topo_order.each do |name|
          declaration = find_declaration(name)
          next unless declaration
          
          instruction = generate_instruction(declaration)
          instructions << instruction if instruction
        end
        
        instructions
      end

      def find_declaration(name)
        # Get declarations from the AST
        (@syntax_tree.attributes + @syntax_tree.traits).find { |decl| decl.name == name }
      end

      def generate_instruction(declaration)
        # Determine operation type from broadcast detector metadata
        detector_metadata = @state[:detector_metadata] || {}
        decl_meta = detector_metadata[declaration.name] || {}
        operation_type = decl_meta[:operation_type] || :scalar
        
        # Get base type from inferencer and coordinate with broadcast detector
        base_type = @analysis.decl_types[declaration.name]
        data_type = coordinate_type(base_type, operation_type, decl_meta)
        
        {
          name: declaration.name,
          type: declaration.class.name.split('::').last.downcase.to_sym, # :value_declaration or :trait_declaration
          operation_type: operation_type,
          data_type: data_type,
          compilation: generate_compilation_info(declaration.expression, operation_type, decl_meta)
        }
      end

      def generate_compilation_info(expression, operation_type, metadata)
        case operation_type
        when :scalar
          generate_scalar_compilation(expression)
        when :element_wise
          generate_element_wise_compilation(expression, metadata)
        when :reduction
          generate_reduction_compilation(expression, metadata)
        when :array_reference
          generate_array_reference_compilation(expression, metadata)
        else
          raise "Unknown operation type: #{operation_type}"
        end
      end

      def generate_scalar_compilation(expression)
        case expression
        when Kumi::Syntax::CallExpression
          {
            type: :call_expression,
            function: expression.fn_name,
            operands: expression.args.map { |arg| generate_operand_info(arg) }
          }
        when Kumi::Syntax::CascadeExpression
          {
            type: :cascade_expression,
            cases: expression.cases.map do |case_expr|
              {
                condition: case_expr.condition ? generate_operand_info(case_expr.condition) : nil,
                result: generate_operand_info(case_expr.result)
              }
            end
          }
        when Kumi::Syntax::ArrayExpression
          {
            type: :array_expression,
            elements: expression.elements.map { |elem| generate_operand_info(elem) }
          }
        when Kumi::Syntax::Literal
          {
            type: :literal,
            value: expression.value
          }
        when Kumi::Syntax::DeclarationReference
          {
            type: :declaration_reference,
            name: expression.name
          }
        else
          raise "Unsupported scalar expression type: #{expression.class}"
        end
      end

      def generate_operand_info(operand)
        case operand
        when Kumi::Syntax::InputReference
          {
            type: :input_reference,
            name: operand.name,
            accessor: "#{operand.name}:structure"
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
        when Kumi::Syntax::InputElementReference
          {
            type: :input_element_reference,
            path: operand.path,
            accessor: "#{operand.path.join('.')}:element"
          }
        when Kumi::Syntax::ArrayExpression
          {
            type: :array_expression,
            elements: operand.elements.map { |elem| generate_operand_info(elem) }
          }
        else
          raise "Unsupported operand type: #{operand.class}"
        end
      end

      # Coordinate type inferencer output with broadcast detector metadata
      def coordinate_type(base_type, operation_type, metadata)
        case operation_type
        when :element_wise
          # Upgrade scalar type to array type based on element-wise strategy
          { array: base_type }
        when :reduction
          # Reduction operations: array input -> scalar output (keep base_type)
          base_type
        else
          # Scalar operations: keep base type
          base_type
        end
      end

      def generate_element_wise_compilation(expression, metadata)
        strategy = metadata[:strategy]
        registry_function = metadata.dig(:registry_call_info, :function_name)
        
        {
          type: :element_wise_operation,
          strategy: strategy,
          function: expression.fn_name,  # Original operation (multiply, add, etc.)
          registry_function: registry_function,  # Broadcasting function (element_wise_object, etc.)
          operands: generate_element_wise_operands(metadata[:operands] || [])
        }
      end

      def generate_element_wise_operands(detector_operands)
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
            when :computed_result
              # TODO: Complex inline expressions should use TAC system instead
              raise "computed_result operands not supported - use TAC system for complex expressions"
            else
              raise "Unsupported source kind: #{source[:kind]} - #{source.inspect}"
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

      def generate_array_reference_compilation(expression, metadata)
        # Direct array field access - just return the operand info
        {
          type: :array_reference,
          operand: generate_operand_info(expression)
        }
      end

      def generate_reduction_compilation(expression, metadata)
        # Reduction operations like fn(:sum, array_operand)
        {
          type: :reduction_operation,
          function: metadata[:function] || expression.fn_name,
          requires_flattening: metadata[:requires_flattening] || false,
          operand: generate_operand_info(expression.args.first)
        }
      end
    end
  end
end