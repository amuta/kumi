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
          return if state[:decl_types] # Already run

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
              add_error(errors, decl&.loc, "Type inference failed: #{e.message}")
            end
          end

          set_state(:decl_types, types)
        end

        private

        def infer_expression_type(expr, type_context = {})
          case expr
          when Syntax::TerminalExpressions::Literal
            Types.infer_from_value(expr.value)
          when Syntax::TerminalExpressions::FieldRef
            # Look up type from field metadata
            input_meta = get_state(:input_meta, required: false) || {}
            meta = input_meta[expr.name]
            meta&.dig(:type) || Types::Base.new
          when Syntax::TerminalExpressions::Binding
            type_context[expr.name] || Types::Base.new
          when Syntax::Expressions::CallExpression
            infer_call_type(expr, type_context)
          when Syntax::Expressions::ListExpression
            infer_list_type(expr, type_context)
          when Syntax::Expressions::CascadeExpression
            infer_cascade_type(expr, type_context)
          else
            Types::Base.new
          end
        end

        def infer_call_type(call_expr, type_context)
          fn_name = call_expr.fn_name
          args = call_expr.args

          # Check if function exists in registry
          unless FunctionRegistry.supported?(fn_name)
            # Don't push error here - let existing TypeChecker handle it
            return Types::Base.new
          end

          signature = FunctionRegistry.signature(fn_name)

          # Validate arity if not variable
          if signature[:arity] >= 0 && args.size != signature[:arity]
            # Don't push error here - let existing TypeChecker handle it
            return Types::Base.new
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

          signature[:return_type] || Types::Base.new
        end

        def infer_list_type(list_expr, type_context)
          return Types.array(Types::Base.new) if list_expr.elements.empty?

          element_types = list_expr.elements.map { |elem| infer_expression_type(elem, type_context) }

          # Try to unify all element types
          unified_type = element_types.reduce { |acc, type| Types.unify(acc, type) }
          Types.array(unified_type)
        rescue StandardError
          # If unification fails, fall back to generic array
          Types.array(Types::Base.new)
        end

        def infer_cascade_type(cascade_expr, type_context)
          return Types::Base.new if cascade_expr.cases.empty?

          # Collect all possible result types
          result_types = []

          cascade_expr.cases.each do |case_stmt|
            case case_stmt
            when Syntax::Expressions::WhenCaseExpression
              result_types << infer_expression_type(case_stmt.result, type_context)
            end
          end

          return Types::Base.new if result_types.empty?

          # Try to unify all result types, but limit to simple unions for v1
          if result_types.size == 1
            result_types.first
          elsif result_types.size == 2
            Types.unify(result_types[0], result_types[1])
          else
            # For more than 2 types, fall back to base type to avoid explosion
            Types::Base.new
          end
        rescue StandardError
          # If unification fails, fall back to base type
          Types::Base.new
        end
      end
    end
  end
end
