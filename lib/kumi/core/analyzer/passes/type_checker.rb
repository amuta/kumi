# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        # RESPONSIBILITY: Validate function call arity and argument types against FunctionRegistry
        # DEPENDENCIES: :inferred_types from TypeInferencer
        # PRODUCES: :functions_required - Set of function names used in the schema
        # INTERFACE: new(schema, state).run(errors)
        class TypeChecker < VisitorPass
          def run(errors)
            functions_required = Set.new

            visit_nodes_of_type(Kumi::Syntax::CallExpression, errors: errors) do |node, _decl, errs|
              validate_function_call(node, errs)
              functions_required.add(node.fn_name)
            end

            state.with(:functions_required, functions_required)
          end

          private

          def validate_function_call(node, errors)
            signature = get_function_signature(node, errors)
            return unless signature

            validate_arity(node, signature, errors)
            validate_argument_types(node, signature, errors)
          end

          def get_function_signature(node, errors)
            Kumi::Registry.signature(node.fn_name)
          rescue Kumi::Errors::UnknownFunction
            # Use old format for backward compatibility, but node.loc provides better location
            report_error(errors, "unsupported operator `#{node.fn_name}`", location: node.loc, type: :type)
            nil
          end

          def validate_arity(node, signature, errors)
            expected_arity = signature[:arity]
            actual_arity = node.args.size

            return if expected_arity.negative? || expected_arity == actual_arity

            report_error(errors, "operator `#{node.fn_name}` expects #{expected_arity} args, got #{actual_arity}", location: node.loc,
                                                                                                                   type: :type)
          end

          def validate_argument_types(node, signature, errors)
            types = signature[:param_types]
            return if types.nil? || (signature[:arity].negative? && node.args.empty?)

            # Skip type checking for vectorized operations
            broadcast_meta = get_state(:broadcasts, required: false)
            return if broadcast_meta && is_part_of_vectorized_operation?(node, broadcast_meta)

            node.args.each_with_index do |arg, i|
              validate_argument_type(arg, i, types[i], node.fn_name, errors)
            end
          end

          def is_part_of_vectorized_operation?(node, broadcast_meta)
            # Check if this node is part of a vectorized or reduction operation
            # This is a simplified check - in a real implementation we'd need to track context
            node.args.any? do |arg|
              case arg
              when Kumi::Syntax::DeclarationReference
                broadcast_meta[:vectorized_operations]&.key?(arg.name) ||
                  broadcast_meta[:reduction_operations]&.key?(arg.name)
              when Kumi::Syntax::InputElementReference
                broadcast_meta[:array_fields]&.key?(arg.path.first)
              else
                false
              end
            end
          end

          def validate_argument_type(arg, index, expected_type, fn_name, errors)
            return if expected_type.nil? || expected_type == Kumi::Core::Types::ANY

            # Get the inferred type for this argument
            actual_type = get_expression_type(arg)
            return if Kumi::Core::Types.compatible?(actual_type, expected_type)

            # Generate descriptive error message
            source_desc = describe_expression_type(arg, actual_type)
            report_error(errors, "argument #{index + 1} of `fn(:#{fn_name})` expects #{expected_type}, " \
                                 "got #{source_desc}", location: arg.loc, type: :type)
          end

          def get_expression_type(expr)
            case expr
            when Kumi::Syntax::Literal
              # Inferred type from literal value
              Kumi::Core::Types.infer_from_value(expr.value)

            when Kumi::Syntax::InputReference
              # Declared type from input block (user-specified)
              get_declared_field_type(expr.name)

            when Kumi::Syntax::DeclarationReference
              # Inferred type from type inference results
              get_inferred_declaration_type(expr.name)

            else
              # For complex expressions, we should have type inference results
              # This is a simplified approach - in reality we'd need to track types for all expressions
              Kumi::Core::Types::ANY
            end
          end

          def get_declared_field_type(field_name)
            # Get explicitly declared type from input metadata
            input_meta = get_state(:input_metadata, required: false) || {}
            field_meta = input_meta[field_name]
            field_meta&.dig(:type) || Kumi::Core::Types::ANY
          end

          def get_inferred_declaration_type(decl_name)
            # Get inferred type from type inference results
            decl_types = get_state(:inferred_types, required: true)
            decl_types[decl_name] || Kumi::Core::Types::ANY
          end

          def describe_expression_type(expr, type)
            case expr
            when Kumi::Syntax::Literal
              "`#{expr.value}` of type #{type} (literal value)"

            when Kumi::Syntax::InputReference
              input_meta = get_state(:input_metadata, required: false) || {}
              field_meta = input_meta[expr.name]

              if field_meta&.dig(:type)
                # Explicitly declared type
                domain_desc = field_meta[:domain] ? " (domain: #{field_meta[:domain]})" : ""
                "input field `#{expr.name}` of declared type #{type}#{domain_desc}"
              else
                # Undeclared field
                "undeclared input field `#{expr.name}` (inferred as #{type})"
              end

            when Kumi::Syntax::DeclarationReference
              # This type was inferred from the declaration's expression
              "reference to declaration `#{expr.name}` of inferred type #{type}"

            when Kumi::Syntax::CallExpression
              "result of function `#{expr.fn_name}` returning #{type}"

            when Kumi::Syntax::ArrayExpression
              "list expression of type #{type}"

            when Kumi::Syntax::CascadeExpression
              "cascade expression of type #{type}"

            else
              "expression of type #{type}"
            end
          end
        end
      end
    end
  end
end
