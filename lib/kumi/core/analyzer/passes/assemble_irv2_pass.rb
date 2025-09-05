# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        # Assembles the final IRv2 JSON structure from analyzer state
        #
        # Input:  state[:irv2_module], state[:ir_input_plans]
        # Output: state[:irv2] (complete JSON structure ready for serialization)
        class AssembleIRV2Pass < PassBase
          def run(errors)
            irv2_module = get_state(:irv2_module, required: true)
            input_plans = get_state(:ir_input_plans, required: true)

            irv2_structure = build_irv2_structure(irv2_module, input_plans, errors)
            debug "Assembled IRv2 structure with #{irv2_structure['declarations'].size} declarations"

            state.with(:irv2, irv2_structure.freeze)
          end

          private

          def build_irv2_structure(irv2_module, input_plans, _errors)
            {
              "version"      => IR_SCHEMA_VERSION,
              "module"       => determine_module_name(irv2_module),
              "declarations" => build_declarations(irv2_module.declarations),
              "analysis"     => build_analysis_section(input_plans, irv2_module.metadata)
            }
          end

          def determine_module_name(irv2_module)
            irv2_module.metadata.dig("module_name") || "schema_module"
          end

          def build_declarations(declarations_hash)
            result = {}
            declarations_hash.each do |name, declaration|
              result[name.to_s] = build_declaration_structure(declaration)
            end
            result
          end

          def build_declaration_structure(declaration)
            {
              "name"        => declaration.name.to_s,
              "parameters"  => build_parameters(declaration.parameters),
              "operations"  => build_operations(declaration.operations, declaration.name),
              "result"      => declaration.result.id
            }
          end

          def build_parameters(parameters)
            parameters.map do |param|
              case param[:type]
              when :input
                { "kind" => "input", "path" => param[:source] }
              when :dependency
                { "kind" => "dependency", "source" => param[:source] }
              else
                param
              end
            end
          end

          def build_operations(operations, _current_decl_name)
            operations.map do |op|
              h = {
                "id"   => op.id,
                "op"   => op.op.to_s,
                "args" => build_operation_args(op.args)
              }
              h["stamp"]       = op.stamp if op.stamp
              h["elem_stamps"] = op.elem_stamps if op.elem_stamps
              attrs = build_operation_attrs(op.attrs)
              h["attrs"] = attrs unless attrs.empty?
              h
            end
          end

          def build_operation_args(args)
            args.map { |arg| arg.respond_to?(:id) ? arg.id : arg }
          end

          def build_operation_attrs(attrs)
            attrs.each_with_object({}) { |(k, v), h| h[k.to_s] = v }
          end

          def build_analysis_section(input_plans, _metadata)
            {
              "defaults" => {
                "key_policy" => "indifferent",
                "on_missing" => "error"
              },
              "inputs" => build_canonical_inputs(input_plans)
            }
          end

          def build_canonical_inputs(input_plans)
            input_plans.map do |plan|
              result = {
                "path"         => Array(plan.source_path).map(&:to_s),
                "axes"         => Array(plan.axes).map(&:to_s),
                "dtype"        => plan.dtype.to_s,
                "key_policy"   => plan.key_policy.to_s,
                "on_missing"   => plan.missing_policy.to_s,
                "axis_loops"   => Array(plan.axis_loops).map { |x| stringify_deep(x) },
                "leaf_nav"     => Array(plan.leaf_nav).map   { |x| stringify_deep(x) },
                "terminal"     => stringify_deep(plan.terminal || { kind: :none }),
                "path_fqn"     => (plan.path_fqn || Array(plan.source_path).map(&:to_s).join("."))
              }
              result
            end
          end

          def stringify_deep(obj)
            case obj
            when Hash
              obj.each_with_object({}) { |(k, v), h| h[k.to_s] = stringify_deep(v) }
            when Array
              obj.map { |v| stringify_deep(v) }
            when Symbol
              obj.to_s
            else
              obj
            end
          end
        end
      end
    end
  end
end
