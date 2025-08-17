# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        # RESPONSIBILITY:
        #   - Compute result dtypes for CallExpressions using RegistryV2 function metadata
        #   - Update inferred types for value declarations based on computed result dtypes
        #   - Validate function existence/arity and argument type constraints via RegistryV2
        #   - Ensure proper ordering: dtype computation → type inference → constraint validation
        #
        # DEPENDS ON:
        #   - CallNameNormalizePass (to set :qualified_name on CallExpression metadata)
        #   - FunctionSignaturePass (may pre-compute :result_dtype, but we compute if missing)
        #   - TypeInferencerPass (to populate initial :inferred_types for DeclarationReference)
        #
        # PRODUCES / TOUCHES:
        #   - :inferred_types (updated with CallExpression result dtypes for value declarations)
        #   - :functions_required (Set of fully-qualified function names used)
        #   - node_index metadata with :result_dtype for CallExpression nodes
        #
        # PASS STRUCTURE:
        #   1. Compute result dtypes for all CallExpressions (post-order traversal)
        #   2. Update inferred_types from computed result dtypes
        #   3. Validate argument constraints with updated inferred_types
        #
        class TypeCheckerV2 < VisitorPass
          def run(errors)
            validator = Kumi::Core::Analyzer::Validators::CallTypeValidator.new(
              registry_v2: registry_v2,
              state: state
            )

            # Three-pass approach:
            # Pass 1: Compute result dtypes for all CallExpressions (post-order)
            visit_post_order_nodes_of_type(Kumi::Syntax::CallExpression, errors: errors) do |node, _decl, errs|
              validator.compute_result_dtype!(node, errs)
            end

            # Pass 2: Update inferred types from CallExpression result dtypes BEFORE validation
            updated_state = update_inferred_types_from_call_expressions(validator)
            
            # Create new validator with updated state for constraint validation
            validator_with_updated_state = Kumi::Core::Analyzer::Validators::CallTypeValidator.new(
              registry_v2: registry_v2,
              state: updated_state
            )
            validator_with_updated_state.instance_variable_set(:@functions_required, validator.functions_required)

            # Pass 3: Validate argument constraints with updated inferred types
            visit_nodes_of_type(Kumi::Syntax::CallExpression, errors: errors) do |node, _decl, errs|
              validator_with_updated_state.validate_constraints!(node, errs)
            end

            updated_state.with(:functions_required, validator_with_updated_state.functions_required)
          end

          private

          def update_inferred_types_from_call_expressions(validator)
            # Update the inferred types for value declarations based on their CallExpression result_dtypes
            node_index = state[:node_index]
            raise "Missing required state: node_index" unless node_index
            
            inferred_types = state[:inferred_types] 
            raise "Missing required state: inferred_types" unless inferred_types
            inferred_types = inferred_types.dup
            
            each_decl do |decl|
              next unless decl.is_a?(Kumi::Syntax::ValueDeclaration)
              next unless decl.expression.is_a?(Kumi::Syntax::CallExpression)
              
              entry = node_index[decl.expression.object_id]
              raise "Missing node_index entry for CallExpression #{decl.expression.object_id}" unless entry
              
              meta = entry[:metadata]
              raise "Missing metadata for CallExpression #{decl.expression.object_id}" unless meta
              
              result_dtype = meta[:result_dtype]
              if result_dtype
                inferred_types[decl.name] = result_dtype
                if ENV["DEBUG_TYPE_CHECKER"]
                  puts "  Updated inferred type for declaration #{decl.name}: #{result_dtype}"
                end
              end
            end
            
            # Return updated state instead of modifying validator's state
            state.with(:inferred_types, inferred_types)
          end

          # Post-order traversal: visit children first, then parent
          def visit_post_order(node, &block)
            return unless node

            node.children.each { |child| visit_post_order(child, &block) }
            yield(node)
          end

          def visit_post_order_nodes_of_type(*node_types, errors:)
            each_decl do |decl|
              visit_post_order(decl.expression) do |node|
                yield(node, decl, errors) if node_types.any? { |type| node.is_a?(type) }
              end
            end
          end
        end
      end
    end
  end
end