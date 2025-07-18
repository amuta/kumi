# frozen_string_literal: true

module Kumi
  module Analyzer
    module Passes
      # RESPONSIBILITY: Validate function call arity and argument types against FunctionRegistry
      # DEPENDENCIES: None (can run independently)
      # PRODUCES: None (validation only)
      # INTERFACE: new(schema, state).run(errors)
      class TypeChecker < VisitorPass
        def run(errors)
          visit_nodes_of_type(Expressions::CallExpression, errors: errors) do |node, _decl, errs|
            validate_function_call(node, errs)
          end
        end

        private

        def validate_function_call(node, errors)
          signature = get_function_signature(node.fn_name, errors)
          return unless signature

          validate_arity(node, signature, errors)
          validate_argument_types(node, signature, errors)
        end

        def get_function_signature(fn_name, errors)
          FunctionRegistry.signature(fn_name)
        rescue FunctionRegistry::UnknownFunction
          add_error(errors, nil, "unsupported operator `#{fn_name}`")
          nil
        end

        def validate_arity(node, signature, errors)
          expected_arity = signature[:arity]
          actual_arity = node.args.size

          return if expected_arity.negative? || expected_arity == actual_arity

          add_error(errors, node.loc,
                    "operator `#{node.fn_name}` expects #{expected_arity} args, got #{actual_arity}")
        end

        def validate_argument_types(node, signature, errors)
          types = signature[:param_types]
          return if types.nil? || (signature[:arity].negative? && node.args.empty?)

          node.args.each_with_index do |arg, i|
            validate_argument_type(arg, i, types[i], node.fn_name, errors)
          end
        end

        def validate_argument_type(arg, index, expected_type, fn_name, errors)
          return if expected_type.nil? || expected_type == Kumi::Types::ANY

          # Get the inferred type for this argument
          actual_type = get_expression_type(arg)
          return if Kumi::Types.compatible?(actual_type, expected_type)

          # Generate descriptive error message
          source_desc = describe_expression_type(arg, actual_type)
          add_error(errors, arg.loc,
                    "argument #{index + 1} of `fn(:#{fn_name})` expects #{expected_type}, " \
                    "got #{source_desc}")
        end

        def get_expression_type(expr)
          case expr
          when TerminalExpressions::Literal
            # Inferred type from literal value
            Kumi::Types.infer_from_value(expr.value)

          when TerminalExpressions::FieldRef
            # Declared type from input block (user-specified)
            get_declared_field_type(expr.name)

          when TerminalExpressions::Binding
            # Inferred type from type inference results
            get_inferred_declaration_type(expr.name)

          else
            # For complex expressions, we should have type inference results
            # This is a simplified approach - in reality we'd need to track types for all expressions
            Kumi::Types::ANY
          end
        end

        def get_declared_field_type(field_name)
          # Get explicitly declared type from input metadata
          input_meta = get_state(:input_meta, required: false) || {}
          field_meta = input_meta[field_name]
          field_meta&.dig(:type) || Kumi::Types::ANY
        end

        def get_inferred_declaration_type(decl_name)
          # Get inferred type from type inference results
          decl_types = get_state(:decl_types, required: true)
          decl_types[decl_name] || Kumi::Types::ANY
        end

        def describe_expression_type(expr, type)
          case expr
          when TerminalExpressions::Literal
            "`#{expr.value}` of type #{type} (literal value)"

          when TerminalExpressions::FieldRef
            input_meta = get_state(:input_meta, required: false) || {}
            field_meta = input_meta[expr.name]

            if field_meta&.dig(:type)
              # Explicitly declared type
              domain_desc = field_meta[:domain] ? " (domain: #{field_meta[:domain]})" : ""
              "input field `#{expr.name}` of declared type #{type}#{domain_desc}"
            else
              # Undeclared field
              "undeclared input field `#{expr.name}` (inferred as #{type})"
            end

          when TerminalExpressions::Binding
            # This type was inferred from the declaration's expression
            "reference to declaration `#{expr.name}` of inferred type #{type}"

          when Expressions::CallExpression
            "result of function `#{expr.fn_name}` returning #{type}"

          when Expressions::ListExpression
            "list expression of type #{type}"

          when Expressions::CascadeExpression
            "cascade expression of type #{type}"

          else
            "expression of type #{type}"
          end
        end
      end
    end
  end
end
