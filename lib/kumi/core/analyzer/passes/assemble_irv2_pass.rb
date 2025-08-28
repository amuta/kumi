# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        # Assembles the final IRv2 JSON structure from analyzer state
        #
        # Input: state[:irv2_module], state[:ir_input_plans] 
        # Output: state[:irv2] (complete JSON structure ready for serialization)
        class AssembleIRV2Pass < PassBase
          def run(errors)
            irv2_module = get_state(:irv2_module, required: true)
            input_plans = get_state(:ir_input_plans, required: true)

            irv2_structure = build_irv2_structure(irv2_module, input_plans, errors)

            debug "Assembled IRv2 structure with #{irv2_structure["declarations"].size} declarations"

            state.with(:irv2, irv2_structure.freeze)
          end

          private

          def build_irv2_structure(irv2_module, input_plans, errors)
            {
              "$schema" => "https://kumi.dev/schema/irv2-core.schema.json",
              "version" => "2.0",
              "module" => determine_module_name(irv2_module),
              "declarations" => build_declarations(irv2_module.declarations),
              "analysis" => build_analysis_section(input_plans)
            }
          end

          def determine_module_name(irv2_module)
            # Try to extract a meaningful name from the module
            # For now, use a generic name or extract from metadata
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
              "name" => declaration.name.to_s,
              "parameters" => build_parameters(declaration.parameters),
              "operations" => build_operations(declaration.operations),
              "result" => declaration.result.id
            }
          end

          def build_parameters(parameters)
            parameters.map do |param|
              case param[:type]
              when :input
                {
                  "type" => "input",
                  "name" => param[:name],
                  "path" => param[:path],
                  "axes" => param[:axes],
                  "dtype" => param[:dtype]
                }
              when :dependency
                {
                  "type" => "dependency", 
                  "name" => param[:name],
                  "source" => param[:source],
                  "axes" => param[:axes],
                  "dtype" => param[:dtype]
                }
              else
                param  # Pass through unknown parameter types
              end
            end
          end

          def build_operations(operations)
            operations.map do |op|
              {
                "id" => op.id,
                "op" => op.op.to_s,
                "args" => build_operation_args(op.args),
                "attrs" => build_operation_attrs(op.attrs)
              }
            end
          end

          def build_operation_args(args)
            args.map do |arg|
              if arg.respond_to?(:id)
                arg.id  # Reference to another operation
              else
                arg     # Literal value
              end
            end
          end

          def build_operation_attrs(attrs)
            result = {}
            attrs.each do |key, value|
              result[key.to_s] = value
            end
            result
          end

          def build_analysis_section(input_plans)
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
              {
                "path" => plan.path,
                "axes" => plan.axes, 
                "dtype" => plan.dtype,
                "key_policy" => plan.key_policy,
                "on_missing" => plan.on_missing,
                "chain" => plan.access_chain
              }
            end
          end
        end
      end
    end
  end
end
