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

            # Assert each input has the new axis_loops format
            pack["inputs"].each_with_index do |input, i|
              raise KeyError, "inputs[#{i}] missing axis_loops" unless input["axis_loops"].is_a?(Array)
              raise KeyError, "inputs[#{i}] missing leaf_nav"   unless input["leaf_nav"].is_a?(Array)
              raise KeyError, "inputs[#{i}] missing terminal"   unless input["terminal"].is_a?(Hash)
              raise KeyError, "inputs[#{i}] missing path_fqn"   unless input["path_fqn"].is_a?(String)
              
              # Validate axis_loops structure
              input["axis_loops"].each_with_index do |step, j|
                raise KeyError, "inputs[#{i}].axis_loops[#{j}] missing loop_idx" unless step["loop_idx"].is_a?(Integer)
                raise KeyError, "inputs[#{i}].axis_loops[#{j}] invalid kind" unless %w[array_field array_element].include?(step["kind"])
                if step["kind"] == "array_field"
                  raise KeyError, "inputs[#{i}].axis_loops[#{j}] array_field missing key" unless step["key"]
                end
              end
              
              # Validate leaf_nav structure
              input["leaf_nav"].each_with_index do |step, j|
                raise KeyError, "inputs[#{i}].leaf_nav[#{j}] missing kind" unless step["kind"]
                raise KeyError, "inputs[#{i}].leaf_nav[#{j}] invalid kind" unless %w[field_leaf element_leaf].include?(step["kind"])
              end
                
              # Validate terminal structure
              raise KeyError, "inputs[#{i}].terminal missing kind" unless input["terminal"]["kind"]
            end

            true
          end
        end
      end
    end
  end
end
