# frozen_string_literal: true

module Kumi
  module Analyzer
    module Passes
      # RESPONSIBILITY: Infer types for all declarations based on expression analysis
      # DEPENDENCIES: Toposorter (needs topo_order), DefinitionValidator (needs definitions)
      # PRODUCES: decl_types hash mapping declaration names to inferred types
      # INTERFACE: new(schema, state).run(errors)
      class TypeInferencer < PassBase
        def run(errors)
          types = {}
          topo_order = get_state(:topo_order)
          definitions = get_state(:definitions)

          # Process declarations in topological order to ensure dependencies are resolved
          topo_order.each do |name|
            decl = definitions[name]
            next unless decl

            begin
              inferred_type = infer_expression_type(decl.expression, types)
              types[name] = inferred_type
            rescue StandardError => e
              report_type_error(errors, "Type inference failed: #{e.message}", location: decl&.loc)
            end
          end

          state.with(:decl_types, types)
        end

        private

        def infer_expression_type(expr, type_context = {})
          case expr
          when Literal
            Types.infer_from_value(expr.value)
          when FieldRef
            # Look up type from field metadata
            input_meta = get_state(:input_meta, required: false) || {}
            meta = input_meta[expr.name]
            meta&.dig(:type) || :any
          when Binding
            type_context[expr.name] || :any
          when CallExpression
            infer_call_type(expr, type_context)
          when ListExpression
            infer_list_type(expr, type_context)
          when CascadeExpression
            infer_cascade_type(expr, type_context)
          else
            :any
          end
        end

        def infer_call_type(call_expr, type_context)
          fn_name = call_expr.fn_name
          args = call_expr.args

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
          arg_types = args.map { |arg| infer_expression_type(arg, type_context) }

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

        def infer_list_type(list_expr, type_context)
          return Types.array(:any) if list_expr.elements.empty?

          element_types = list_expr.elements.map { |elem| infer_expression_type(elem, type_context) }

          # Try to unify all element types
          unified_type = element_types.reduce { |acc, type| Types.unify(acc, type) }
          Types.array(unified_type)
        rescue StandardError
          # If unification fails, fall back to generic array
          Types.array(:any)
        end

        def infer_cascade_type(cascade_expr, type_context)
          return :any if cascade_expr.cases.empty?

          result_types = cascade_expr.cases.map do |case_stmt|
            infer_expression_type(case_stmt.result, type_context)
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
