# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        # RESPONSIBILITY: Validate function call arity and argument types against FunctionRegistry
        # DEPENDENCIES: :inferred_types from TypeInferencerPass
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
            # Get metadata from node_index that should be populated by earlier passes
            node_index = get_state(:node_index, required: false)
            entry = node_index&.dig(node.object_id)
            metadata = entry&.dig(:metadata) || {}
            
            # Skip if skip_signature flag is set (e.g., for cascade_and identity cases)
            return if metadata[:skip_signature]
            
            # Use metadata-first approach - if signature is available from FunctionSignaturePass, use it
            if metadata[:signature]
              validate_with_metadata(node, metadata, errors)
            else
              # Fallback to basic validation for nodes that don't have NEP-20 signatures
              validate_basic_function_call(node, metadata, errors)
            end
          end

          def validate_with_metadata(node, metadata, errors)
            # Use resolved function name and RegistryV2 for type checking
            fn_name = resolved_fn_name(metadata, node)
            
            function = registry_v2.resolve(fn_name.to_s, arity: node.args.size)
            
            # Store function class in metadata if not already set
            metadata[:fn_class] ||= function.class if metadata
            
            # Compute result dtype if function has dtypes
            if function.dtypes && function.dtypes[:result] && metadata
              metadata[:result_dtype] = function.dtypes[:result]
            end
            
            # Validate argument types against function type constraints
            validate_argument_type_constraints(node, function, errors)
            
            if ENV["DEBUG_TYPE_CHECKER"]
              puts("  TypeCheck call_id=#{node.object_id} qualified=#{fn_name} fn_class=#{metadata[:fn_class]} status=validated")
            end
          end
          
          def validate_basic_function_call(node, metadata, errors)
            # Basic validation for functions without full RegistryV2 support
            # This is mainly for compatibility during migration
            fn_name = resolved_fn_name(metadata, node)
            
            if ENV["DEBUG_TYPE_CHECKER"]
              puts("  TypeCheck call_id=#{node.object_id} qualified=#{fn_name} status=basic_validation")
            end
            
            # Just check if the function exists in RegistryV2
            registry_v2.resolve(fn_name.to_s, arity: node.args.size)
          rescue KeyError => e
            report_error(errors, "Unknown function `#{fn_name}` with arity #{node.args.size}: #{e.message}",
                        location: node.loc, type: :type)
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

          def validate_argument_type_constraints(node, function, errors)
            # Skip validation if no type constraints are defined
            return unless function.type_vars && !function.type_vars.empty?

            # Skip type checking for vectorized operations
            broadcast_meta = get_state(:broadcasts, required: false)
            return if broadcast_meta && is_part_of_vectorized_operation?(node, broadcast_meta)

            # For now, map type variable names to their constraints
            # T: Numeric means T must be a numeric type (integer, float)  
            # T: Orderable means T must be an orderable type (integer, float, string, etc.)
            type_var_names = function.type_vars.keys
            
            # Validate each argument against its corresponding type constraint
            node.args.each_with_index do |arg, i|
              # Get the type variable for this argument position
              # For binary functions like gt(T, U), we expect type_vars = {T: constraint1, U: constraint2}
              type_var_name = type_var_names[i] || type_var_names.first # Fallback to first constraint
              next unless type_var_name

              constraint = function.type_vars[type_var_name]
              actual_type = get_expression_type(arg)
              
              unless satisfies_type_constraint?(actual_type, constraint)
                # Generate error message matching the expected format
                expected_desc = constraint_to_expected_type(constraint)
                source_desc = describe_expression_type(arg, actual_type)
                # Use the original function name from the node for the error message
                original_fn_name = node.fn_name
                report_error(errors, "argument #{i + 1} of `fn(:#{original_fn_name})` expects #{expected_desc}, " \
                                     "got #{source_desc}", location: arg.loc, type: :type)
              end
            end
          end

          def satisfies_type_constraint?(type, constraint)
            case constraint.to_s.downcase
            when "numeric"
              # Numeric constraint: accepts integer, float
              %i[integer float].include?(type)
            when "orderable"
              # Orderable constraint: accepts integer, float, string (for now)
              # This is a more restrictive interpretation - string/integer comparison should fail
              %i[integer float].include?(type)
            else
              # Unknown constraint, be permissive for now
              true
            end
          end

          def constraint_to_expected_type(constraint)
            case constraint.to_s.downcase
            when "numeric"
              "float" # Use "float" to match existing error messages 
            when "orderable"
              "float" # Use "float" to match existing error messages  
            else
              constraint.to_s
            end
          end
        end
      end
    end
  end
end
