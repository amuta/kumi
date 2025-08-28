# frozen_string_literal: true

require "set"

module Kumi
  module Core
    module Analyzer
      module Passes
        class ContractCheckerPass < PassBase
          # In:  state[:snast_module], state[:input_table]
          # Out: validates contracts and reports errors
          def run(errors)
            snast_module = get_state(:snast_module, required: true)
            input_table = get_state(:input_table, required: true)
            evaluation_order = get_state(:evaluation_order, required: true)

            validate_snast_structure(snast_module, errors)
            validate_input_table(input_table, errors)
            validate_snast_consistency(snast_module, input_table, errors)
            validate_evaluation_order_consistency(snast_module, evaluation_order, errors)
            validate_snast_metadata_requirements(snast_module, errors)

            state
          end

          private

          def validate_snast_structure(snast_module, errors)
            unless snast_module.respond_to?(:decls)
              errors << "SNAST module missing declarations"
              return
            end

            unless snast_module.decls.is_a?(Hash)
              errors << "SNAST module declarations must be a Hash"
              return
            end

            errors << "SNAST module must have at least one declaration" if snast_module.decls.empty?

            snast_module.decls.each do |name, decl|
              validate_snast_declaration(name, decl, errors)
            end
          end

          def validate_snast_declaration(name, decl, errors)
            errors << "SNAST declaration #{name} missing body" unless decl.respond_to?(:body)

            validate_snast_node(name, decl.body, errors) if decl.respond_to?(:body)
          end

          def validate_snast_node(decl_name, node, errors)
            return unless node

            case node
            when Kumi::Core::NAST::Const
              # Constants are always valid
            when Kumi::Core::NAST::InputRef
              validate_input_ref(decl_name, node, errors)
            when Kumi::Core::NAST::Ref
              validate_declaration_ref(decl_name, node, errors)
            when Kumi::Core::NAST::TupleLiteral
              validate_tuple_literal(decl_name, node, errors)
            when Kumi::Core::NAST::Call
              validate_call_node(decl_name, node, errors)
            else
              errors << "Declaration #{decl_name} contains unknown SNAST node type: #{node.class}"
            end
          end

          def validate_input_ref(decl_name, node, errors)
            unless node.respond_to?(:path)
              errors << "Declaration #{decl_name} InputRef missing path"
              return
            end

            errors << "Declaration #{decl_name} InputRef path must be Array" unless node.path.is_a?(Array)

            return unless node.path.empty?

            errors << "Declaration #{decl_name} InputRef path cannot be empty"
          end

          def validate_declaration_ref(decl_name, node, errors)
            return if node.respond_to?(:name)

            errors << "Declaration #{decl_name} Ref missing name"
          end

          def validate_tuple_literal(decl_name, node, errors)
            unless node.respond_to?(:elements)
              errors << "Declaration #{decl_name} TupleLiteral missing elements"
              return
            end

            unless node.elements.is_a?(Array)
              errors << "Declaration #{decl_name} TupleLiteral elements must be Array"
              return
            end

            node.elements.each do |element|
              validate_snast_node(decl_name, element, errors)
            end
          end

          def validate_call_node(decl_name, node, errors)
            errors << "Declaration #{decl_name} Call missing function name" unless node.respond_to?(:fn)

            unless node.respond_to?(:args)
              errors << "Declaration #{decl_name} Call missing arguments"
              return
            end

            unless node.args.is_a?(Array)
              errors << "Declaration #{decl_name} Call arguments must be Array"
              return
            end

            node.args.each do |arg|
              validate_snast_node(decl_name, arg, errors)
            end
          end

          def validate_input_table(input_table, errors)
            unless input_table.is_a?(Hash)
              errors << "Input table must be a Hash"
              return
            end

            input_table.each do |path, info|
              validate_input_table_entry(path, info, errors)
            end
          end

          def validate_input_table_entry(path, info, errors)
            errors << "Input table path must be Array, got: #{path.class}" unless path.is_a?(Array)

            unless info.is_a?(Hash)
              errors << "Input table info must be Hash for path #{path.inspect}"
              return
            end

            required_keys = %i[axis dtype]
            required_keys.each do |key|
              errors << "Input table entry #{path.inspect} missing key: #{key}" unless info.key?(key)
            end

            return unless info[:axis] && !info[:axis].is_a?(Array)

            errors << "Input table entry #{path.inspect} axis must be Array"
          end

          def validate_snast_consistency(snast_module, input_table, errors)
            # Collect all input references from SNAST
            referenced_paths = collect_input_references(snast_module)

            # Check that all referenced paths exist in input table
            referenced_paths.each do |path|
              errors << "SNAST references undefined input path: #{path.inspect}" unless input_table.key?(path)
            end

            # Check for unused input table entries (optional warning)
            input_table.keys.each do |path|
              unless referenced_paths.include?(path)
                # This is just a warning, not an error
              end
            end
          end

          def collect_input_references(snast_module)
            references = Set.new

            snast_module.decls.each do |_, decl|
              collect_input_refs_from_node(decl.body, references) if decl.respond_to?(:body)
            end

            references
          end

          def collect_input_refs_from_node(node, references)
            return unless node

            case node
            when Kumi::Core::NAST::InputRef
              references.add(node.path) if node.respond_to?(:path)
            when Kumi::Core::NAST::TupleLiteral
              node.elements.each { |elem| collect_input_refs_from_node(elem, references) } if node.respond_to?(:elements)
            when Kumi::Core::NAST::Call
              node.args.each { |arg| collect_input_refs_from_node(arg, references) } if node.respond_to?(:args)
            end
          end

          def validate_evaluation_order_consistency(snast_module, evaluation_order, errors)
            # Ensure all declarations in evaluation order exist in SNAST module
            evaluation_order.each do |decl_name|
              unless snast_module.decls.key?(decl_name)
                errors << "Declaration #{decl_name} from evaluation order not found in SNAST module"
              end
            end

            # Ensure all SNAST declarations are included in evaluation order
            snast_module.decls.keys.each do |decl_name|
              unless evaluation_order.include?(decl_name)
                errors << "Declaration #{decl_name} in SNAST module not found in evaluation order"
              end
            end
          end

          def validate_snast_metadata_requirements(snast_module, errors)
            # Validate that all nodes that require plans have them
            snast_module.decls.each do |decl_name, decl|
              validate_node_metadata_requirements(decl_name, decl.body, errors) if decl.respond_to?(:body)
            end
          end

          def validate_node_metadata_requirements(decl_name, node, errors)
            return unless node

            case node
            when Kumi::Core::NAST::TupleLiteral
              errors << "Declaration #{decl_name} TupleLiteral missing required plan metadata" unless node.meta&.[](:plan)
              node.elements.each { |elem| validate_node_metadata_requirements(decl_name, elem, errors) } if node.respond_to?(:elements)

            when Kumi::Core::NAST::Call
              errors << "Declaration #{decl_name} Call #{node.fn} missing required plan metadata" unless node.meta&.[](:plan)

              # Validate plan structure
              if node.meta&.[](:plan)
                plan = node.meta[:plan]
                validate_plan_structure(decl_name, node, plan, errors)
              end

              node.args.each { |arg| validate_node_metadata_requirements(decl_name, arg, errors) } if node.respond_to?(:args)
            end
          end

          def validate_plan_structure(decl_name, node, plan, errors)
            unless plan.is_a?(Hash)
              errors << "Declaration #{decl_name} node plan must be a Hash"
              return
            end

            unless plan.key?(:kind)
              errors << "Declaration #{decl_name} node plan missing :kind"
              return
            end

            case plan[:kind]
            when :reduce
              errors << "Declaration #{decl_name} reduce plan missing :last_axis_token" unless plan.key?(:last_axis_token)

              if node.respond_to?(:args) && node.args.size != 1
                errors << "Declaration #{decl_name} reduce operation must have exactly 1 argument"
              end

            when :elementwise
              if plan[:needs_expand_flags] && plan[:target_axes_tokens].nil?
                errors << "Declaration #{decl_name} elementwise plan with expand flags missing target_axes_tokens"
              end

            else
              errors << "Declaration #{decl_name} plan has unknown kind: #{plan[:kind]}"
            end
          end
        end
      end
    end
  end
end
