# frozen_string_literal: true

# Zeitwerk: Kumi::Codegen::RubyV3::Pipeline::PackSanity

module Kumi
  module Codegen
    module RubyV3
      module Pipeline
        module PackSanity
          module_function

          def run(pack)
            raise KeyError, "declarations missing" unless pack["declarations"].is_a?(Array)
            raise KeyError, "inputs missing"       unless pack["inputs"].is_a?(Array)

            # Assert each input has the new navigation_steps format
            pack["inputs"].each_with_index do |input, i|
              raise KeyError, "inputs[#{i}] missing navigation_steps" unless input["navigation_steps"].is_a?(Array)
              raise KeyError, "inputs[#{i}] missing path_fqn"   unless input["path_fqn"].is_a?(String)
              
              # Validate navigation_steps structure
              input["navigation_steps"].each_with_index do |step, j|
                raise KeyError, "inputs[#{i}].navigation_steps[#{j}] missing loop_idx for array_loop" if  step["kind"] == "array_loop" && !step.key?("loop_idx")
                raise KeyError, "inputs[#{i}].navigation_steps[#{j}] invalid kind `#{step["kind"]}`" unless %w[array_loop property_access].include?(step["kind"])
                if step["kind"] == "array_field"
                  raise KeyError, "inputs[#{i}].navigation_steps[#{j}] array_field missing key" unless step["key"]
                end
              end
            end

            true
          end
        end
      end
    end
  end
end
