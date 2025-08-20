# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        # RESPONSIBILITY: Infer types for all declarations based on expression analysis
        # 
        # Provides initial type inference for all declarations using expression structure,
        # input metadata, and RegistryV2. TypeCheckerV2 will later update inferred_types
        # for value declarations with CallExpression result dtypes computed from RegistryV2.
        #
        # DEPENDENCIES: 
        #   - Toposorter (needs evaluation_order for dependency resolution)
        #   - DeclarationValidator (needs declarations mapping)
        #   - BroadcastDetector (needs broadcasts for vectorized type handling)
        #
        # PRODUCES: 
        #   - inferred_types hash mapping declaration names to inferred types
        #
        # RELATIONSHIP WITH TypeCheckerV2:
        #   - This pass provides initial inferred_types using expression-based inference
        #   - TypeCheckerV2 updates inferred_types for CallExpression-based value declarations
        #   - Final inferred_types combine both passes' contributions
        class TypeInferencerPass < PassBase
          def run(errors)
            types = {}
            registry = get_state(:registry, required: true)
            topo_order = get_state(:evaluation_order)
            definitions = get_state(:declarations)
            input_metadata = get_state(:input_metadata, required: false) || {}

            # Get node_index to annotate expression-level types for AmbiguityResolver
            node_index = get_state(:node_index, required: false) || {}
            updated_node_index = node_index.dup

            # Get broadcast metadata from broadcast detector
            broadcast_meta = get_state(:broadcasts, required: false) || {}

            # Process declarations in topological order to ensure dependencies are resolved
            topo_order.each do |name|
              decl = definitions[name]
              next unless decl

              begin
                # Check if this declaration is actually vectorized (not just scalar with empty dimensional_scope)
                vectorized_info = broadcast_meta[:vectorized_operations]&.[](name)
                is_truly_vectorized = vectorized_info && 
                                     (vectorized_info[:dimensional_scope]&.any? || 
                                      vectorized_info[:source] == :nested_array_access ||
                                      vectorized_info[:source] == :array_field_access ||
                                      vectorized_info[:source] == :nested_array_field ||
                                      vectorized_info[:source] == :vectorized_declaration)
                
                if is_truly_vectorized
                  # Infer the element type and wrap in array
                  element_type = infer_vectorized_element_type(decl.expression, types, broadcast_meta)
                  types[name] = decl.is_a?(Kumi::Syntax::TraitDeclaration) ? { array: :boolean } : { array: element_type }
                else
                  # Normal type inference - also annotate expression nodes
                  inferred_type = infer_expression_type(decl.expression, types, broadcast_meta, name, updated_node_index)
                  types[name] = inferred_type
                end
              rescue StandardError => e
                report_type_error(errors, "Type inference failed: #{e.message}", location: decl&.loc)
              end
            end

            state.with(:inferred_types, types).with(:node_index, updated_node_index)
          end

          private

          def infer_expression_type(expr, type_context = {}, broadcast_metadata = {}, current_decl_name = nil, node_index = nil)
            case expr
            when Literal
              Types.infer_from_value(expr.value)
            when InputReference
              # Look up type from field metadata
              input_meta = get_state(:input_metadata, required: false) || {}
              meta = input_meta[expr.name]
              meta&.dig(:type) || :any
            when DeclarationReference
              type_context[expr.name] || :any
            when CallExpression
              # Infer argument types and annotate node for AmbiguityResolver
              if node_index && expr.respond_to?(:object_id)
                arg_types = expr.args.map { |arg| infer_expression_type(arg, type_context, broadcast_metadata, current_decl_name, node_index) }
                
                # Annotate this CallExpression node with argument type information
                if node_index[expr.object_id]
                  node_index[expr.object_id][:metadata] ||= {}
                  node_index[expr.object_id][:metadata][:inferred_arg_types] = arg_types
                end
              end
              
              infer_call_type(expr, type_context, broadcast_metadata, current_decl_name)
            when ArrayExpression
              infer_list_type(expr, type_context, broadcast_metadata, current_decl_name, node_index)
            when CascadeExpression
              infer_cascade_type(expr, type_context, broadcast_metadata, current_decl_name, node_index)
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

            # Get RegistryV2 from state and use dtypes directly
            registry = get_state(:registry, required: true)
            
            # Check if function exists in registry
            unless registry.function_exists?(fn_name)
              # Don't push error here - let existing TypeChecker handle it
              return :any
            end

            begin
              function = registry.resolve(fn_name)
              
              # Extract return type from dtypes.result field directly
              result_dtype = function.dtypes["result"] || function.dtypes[:result]
              return Types.infer_from_dtype(result_dtype) if result_dtype
              
              # No dtypes.result specified - return :any
              :any
            rescue KeyError
              # Function doesn't exist - let TypeChecker handle validation
              :any
            end
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
            # Get RegistryV2 from state and use dtypes directly
            registry = get_state(:registry, required: true)
            
            return :any unless registry.function_exists?(fn_name)

            begin
              function = registry.resolve(fn_name)
              
              # Extract return type from dtypes.result field directly
              result_dtype = function.dtypes["result"] || function.dtypes[:result]
              return Types.infer_from_dtype(result_dtype) if result_dtype
              
              # No dtypes.result specified - return :any
              :any
            rescue KeyError
              :any
            end
          end

          def infer_list_type(list_expr, type_context, broadcast_metadata = {}, current_decl_name = nil, node_index = nil)
            return Types.array(:any) if list_expr.elements.empty?

            element_types = list_expr.elements.map do |elem|
              infer_expression_type(elem, type_context, broadcast_metadata, current_decl_name, node_index)
            end

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
              input_meta = get_state(:input_metadata, required: false) || {}
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
            input_meta = get_state(:input_metadata, required: false) || {}

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

          def infer_cascade_type(cascade_expr, type_context, broadcast_metadata = {}, current_decl_name = nil, node_index = nil)
            return :any if cascade_expr.cases.empty?

            result_types = cascade_expr.cases.map do |case_stmt|
              infer_expression_type(case_stmt.result, type_context, broadcast_metadata, current_decl_name, node_index)
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
end
