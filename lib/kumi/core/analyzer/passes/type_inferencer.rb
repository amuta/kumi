# frozen_string_literal: true

module Kumi::Core
  module Analyzer
    module Passes
      # RESPONSIBILITY: Infer types for all declarations based on expression analysis
      # DEPENDENCIES: Toposorter (needs evaluation_order), DeclarationValidator (needs declarations)
      # PRODUCES: inferred_types hash mapping declaration names to inferred types
      # INTERFACE: new(schema, state).run(errors)
      class TypeInferencer < PassBase
        def run(errors)
          types = {}
          topo_order = get_state(:evaluation_order)
          definitions = get_state(:declarations)

          # Get broadcast metadata from broadcast detector
          broadcast_meta = get_state(:broadcasts, required: false) || {}

          # Process declarations in topological order to ensure dependencies are resolved
          topo_order.each do |name|
            decl = definitions[name]
            next unless decl

            begin
              # Check if this declaration is marked as vectorized
              if broadcast_meta[:vectorized_operations]&.key?(name)
                # Infer the element type and wrap in array
                element_type = infer_vectorized_element_type(decl.expression, types, broadcast_meta)
                types[name] = decl.is_a?(Kumi::Core::Syntax::TraitDeclaration) ? { array: :boolean } : { array: element_type }
              else
                # Normal type inference
                inferred_type = infer_expression_type(decl.expression, types, broadcast_meta, name)
                types[name] = inferred_type
              end
            rescue StandardError => e
              report_type_error(errors, "Type inference failed: #{e.message}", location: decl&.loc)
            end
          end

          state.with(:inferred_types, types)
        end

        private

        def infer_expression_type(expr, type_context = {}, broadcast_metadata = {}, current_decl_name = nil)
          case expr
          when Literal
            Types.infer_from_value(expr.value)
          when InputReference
            # Look up type from field metadata
            input_meta = get_state(:inputs, required: false) || {}
            meta = input_meta[expr.name]
            meta&.dig(:type) || :any
          when DeclarationReference
            type_context[expr.name] || :any
          when CallExpression
            infer_call_type(expr, type_context, broadcast_metadata, current_decl_name)
          when ArrayExpression
            infer_list_type(expr, type_context, broadcast_metadata, current_decl_name)
          when CascadeExpression
            infer_cascade_type(expr, type_context, broadcast_metadata, current_decl_name)
          when InputElementReference
            # Element reference returns the field type
            infer_element_reference_type(expr)
          else
            :any
          end
        end

        def infer_call_type(call_expr, type_context, broadcast_metadata = {}, current_decl_name = nil)
          fn_name = call_expr.fn_name
          args = call_expr.args

          # Check broadcast metadata first
          if current_decl_name && broadcast_metadata[:vectorized_values]&.key?(current_decl_name)
            # This declaration is marked as vectorized, so it produces an array
            element_type = infer_vectorized_element_type(call_expr, type_context, broadcast_metadata)
            return { array: element_type }
          end

          if current_decl_name && broadcast_metadata[:reducer_values]&.key?(current_decl_name)
            # This declaration is marked as a reducer, get the result from the function
            return infer_function_return_type(fn_name, args, type_context, broadcast_metadata)
          end

          # Check if function exists in registry
          unless FunctionRegistry.supported?(fn_name)
            # Don't push error here - let existing TypeChecker handle it
            return :any
          end

          signature = FunctionRegistry.signature(fn_name)

          # Validate arity if not variable
          if signature[:arity] >= 0 && args.size != signature[:arity]
            # Don't push error here - let existing TypeChecker handle it
            return :any
          end

          # Infer argument types
          arg_types = args.map { |arg| infer_expression_type(arg, type_context, broadcast_metadata, current_decl_name) }

          # Validate parameter types (warn but don't fail)
          param_types = signature[:param_types] || []
          if signature[:arity] >= 0 && param_types.size.positive?
            arg_types.each_with_index do |arg_type, i|
              expected_type = param_types[i] || param_types.last
              next if expected_type.nil?

              unless Types.compatible?(arg_type, expected_type)
                # Could add warning here in future, but for now just infer best type
              end
            end
          end

          signature[:return_type] || :any
        end

        def infer_vectorized_element_type(call_expr, _type_context, _broadcast_metadata)
          # For vectorized arithmetic operations, infer the element type
          # For now, assume arithmetic operations on floats produce floats
          case call_expr.fn_name
          when :multiply, :add, :subtract, :divide
            :float
          else
            :any
          end
        end

        def infer_function_return_type(fn_name, _args, _type_context, _broadcast_metadata)
          # Get the function signature
          return :any unless FunctionRegistry.supported?(fn_name)

          signature = FunctionRegistry.signature(fn_name)
          signature[:return_type] || :any
        end

        def infer_list_type(list_expr, type_context, broadcast_metadata = {}, current_decl_name = nil)
          return Types.array(:any) if list_expr.elements.empty?

          element_types = list_expr.elements.map { |elem| infer_expression_type(elem, type_context, broadcast_metadata, current_decl_name) }

          # Try to unify all element types
          unified_type = element_types.reduce { |acc, type| Types.unify(acc, type) }
          Types.array(unified_type)
        rescue StandardError
          # If unification fails, fall back to generic array
          Types.array(:any)
        end

        def infer_vectorized_element_type(expr, type_context, vectorization_meta)
          # For vectorized operations, we need to infer the element type
          case expr
          when InputElementReference
            # Get the field type from metadata
            input_meta = get_state(:inputs, required: false) || {}
            array_name = expr.path.first
            field_name = expr.path[1]

            array_meta = input_meta[array_name]
            return :any unless array_meta&.dig(:type) == :array

            array_meta.dig(:children, field_name, :type) || :any

          when CallExpression
            # For arithmetic operations, infer from operands
            if %i[add subtract multiply divide].include?(expr.fn_name)
              # Get types of operands
              arg_types = expr.args.map do |arg|
                if arg.is_a?(InputElementReference)
                  infer_vectorized_element_type(arg, type_context, vectorization_meta)
                elsif arg.is_a?(DeclarationReference)
                  # Get the element type if it's vectorized
                  ref_type = type_context[arg.name]
                  if ref_type.is_a?(Hash) && ref_type.key?(:array)
                    ref_type[:array]
                  else
                    ref_type || :any
                  end
                else
                  infer_expression_type(arg, type_context, vectorization_meta)
                end
              end

              # Unify types for arithmetic
              Types.unify(*arg_types) || :float
            else
              :any
            end

          else
            :any
          end
        end

        def infer_element_reference_type(expr)
          # Get array field metadata
          input_meta = get_state(:inputs, required: false) || {}

          return :any unless expr.path.size >= 2

          array_name = expr.path.first
          field_name = expr.path[1]

          array_meta = input_meta[array_name]
          return :any unless array_meta&.dig(:type) == :array

          # Get the field type from children metadata
          field_type = array_meta.dig(:children, field_name, :type) || :any

          # Return array of field type (vectorized)
          { array: field_type }
        end

        def infer_cascade_type(cascade_expr, type_context, broadcast_metadata = {}, current_decl_name = nil)
          return :any if cascade_expr.cases.empty?

          result_types = cascade_expr.cases.map do |case_stmt|
            infer_expression_type(case_stmt.result, type_context, broadcast_metadata, current_decl_name)
          end

          # Reduce all possible types into a single unified type
          result_types.reduce { |unified, type| Types.unify(unified, type) } || :any
        rescue StandardError
          # Check if unification fails, fall back to base type
          # TODO: understand if this right to fallback or we should raise
          :any
        end
      end
    end
  end
end
