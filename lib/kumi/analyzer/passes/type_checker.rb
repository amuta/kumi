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

          return if expected_arity < 0 || expected_arity == actual_arity

          add_error(errors, node.loc, 
                   "operator `#{node.fn_name}` expects #{expected_arity} args, got #{actual_arity}")
        end

        def validate_argument_types(node, signature, errors)
          types = signature[:types]
          return if types.nil? || (signature[:arity].negative? && node.args.empty?)

          node.args.each_with_index do |arg, i|
            validate_argument_type(arg, i, types[i], node.fn_name, errors)
          end
        end

        def validate_argument_type(arg, index, expected_type, fn_name, errors)
          return unless arg.is_a?(TerminalExpressions::Literal)
          return if expected_type.nil? || expected_type == :any

          actual_type = normalize_type(arg.value)
          expected_types = Array(expected_type)

          return if expected_types.include?(actual_type)

          add_error(errors, arg.loc,
                   "argument #{index + 1} of `fn(:#{fn_name})` expects #{expected_types.join(' or ')}, " \
                   "got literal `#{arg.value}` of type #{actual_type}")
        end

        def normalize_type(value)
          type = value.class.name.downcase.to_sym
          type = :numeric if %i[integer float].include?(type)
          type = :string if type == :regexp
          type
        end
      end
    end
  end
end
