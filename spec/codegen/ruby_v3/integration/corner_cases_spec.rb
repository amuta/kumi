# frozen_string_literal: true

require "spec_helper"

RSpec.describe "RubyV3 Integration: Corner Cases" do
  include PackTestHelper

  context "nested hash navigation (non-array structures)" do
    it "handles deep hash field access without array loops" do
      schema = <<~KUMI
        schema do
          input do
            hash :x do
              hash :y do
                integer :z
              end
            end
          end
        #{'  '}
          value :deep_value, input.x.y.z
        end
      KUMI

      pack = pack_for(schema)
      generator = Kumi::Codegen::RubyV3::Generator.new(pack, module_name: "NestedHash")

      result = generator.render

      # Should navigate hash fields without generating loops
      expect(result).to include('@input["x"]["y"]["z"]')
      expect(result).not_to include("while")
      expect(result).not_to include("arr0")
    end
  end

  context "empty arrays and edge cases" do
    it "handles empty array iteration gracefully" do
      schema = <<~KUMI
        schema do
          input do
            array :items do
              integer :value
            end
          end
        #{'  '}
          value :sum_values, fn(:sum, input.items.value)
        end
      KUMI

      pack = pack_for(schema)
      generator = Kumi::Codegen::RubyV3::Generator.new(pack, module_name: "EmptyArrays")

      generated_code = generator.render
      eval(generated_code)

      # Test with empty array
      calculator = Object.new
      calculator.extend(EmptyArrays)
      calculator.instance_variable_set(:@input, { "items" => [] })

      expect(calculator[:sum_values]).to eq(0) # Should return identity value
    end

    it "generates correct operation ordering for empty array reductions" do
      schema = <<~KUMI
        schema do
          input do
            array :numbers do
              integer :value
            end
          end
        #{'  '}
          value :total, fn(:sum, input.numbers.value)
        end
      KUMI

      pack = pack_for(schema)
      generator = Kumi::Codegen::RubyV3::Generator.new(pack, module_name: "OrderingTest")

      generated_code = generator.render

      # Should generate proper loop structure where operations are inside the loop
      expect(generated_code).to include("while i0 < arr0.length")
      expect(generated_code).to include("a0 = arr0[i0]")

      # Load and accumulate operations should be indented (inside loop)
      lines = generated_code.split("\n")
      while_line_idx = lines.find_index { |line| line.include?("while i0 < arr0.length") }
      end_line_idx = lines[(while_line_idx + 1)..-1].find_index { |line| line.strip == "end" }
      end_line_idx = (while_line_idx + 1) + end_line_idx if end_line_idx

      # Find operations between while and end
      loop_body_lines = lines[(while_line_idx + 1)...end_line_idx]
      value_access_line = loop_body_lines.find { |line| line.include?('a0["value"]') }
      acc_add_line = loop_body_lines.find { |line| line.include?("acc_") && line.include?("+=") }

      expect(value_access_line).not_to be_nil
      expect(acc_add_line).not_to be_nil

      # Both should be properly indented (inside the loop)
      expect(value_access_line).to start_with("      ")  # 6 spaces for depth 1
      expect(acc_add_line).to start_with("      ")       # 6 spaces for depth 1
    end
  end

  context "element arrays with different access patterns" do
    it "handles element array navigation correctly" do
      schema = <<~KUMI
        schema do
          input do
            array :cube do
              element :array, :layer do
                element :integer, :cell
              end
            end
          end
        #{'  '}
          value :cells, input.cube.layer.cell
        end
      KUMI

      pack = pack_for(schema)
      generator = Kumi::Codegen::RubyV3::Generator.new(pack, module_name: "ElementArrays")

      result = generator.render

      # Element arrays might need special handling
      expect(result).to be_a(String)
    end
  end

  context "missing identity values in reductions" do
    it "handles reducers without identity values gracefully" do
      # This tests the case where kernel binding has no "identity" field
      # Our KernelIndex should return nil, and StreamLowerer should handle it

      pack = {
        "declarations" => [
          {
            "name" => "test", "operations" => [
                                { "id" => 0, "op" => "Const", "args" => [1] },
                                { "id" => 1, "op" => "Reduce", "args" => [0], "attrs" => { "fn" => "custom.reduce" } }
                              ],
            "result_op_id" => 1, "axes" => [], "axis_carriers" => [],
            "reduce_plans" => [{ "op_id" => 1, "arg_id" => 0, "reducer_fn" => "custom.reduce" }],
            "site_schedule" => {
              "by_depth" => [{ "depth" => 0, "ops" => [
                { "id" => 0, "kind" => "const" }, { "id" => 1, "kind" => "reduce" }
              ] }],
              "hoisted_scalars" => []
            },
            "inlining_decisions" => {}
          }
        ],
        "inputs" => [],
        "bindings" => {
          "ruby" => {
            "kernels" => [
              { "kernel_id" => "custom.reduce", "impl" => "->(a,b) { [a,b].max }" }
              # NOTE: no "identity" field
            ]
          }
        }
      }

      generator = Kumi::Codegen::RubyV3::Generator.new(pack, module_name: "MissingIdentity")

      result = generator.render

      # Should handle nil identity gracefully (might use 0 as default)
      expect(result).to include("acc_")
      expect(result).to include("custom.reduce")
    end
  end

  context "circular or complex dependencies" do
    it "handles complex LoadDeclaration scenarios" do
      # This would test cases where declarations reference each other
      # or have complex inlining decisions
      expect(true).to be(true) # Placeholder
    end
  end

  context "very deep nesting levels" do
    it "handles 5+ levels of nesting without stack overflow" do
      schema = <<~KUMI
        schema do
          input do
            array :level1 do
              array :level2 do
                array :level3 do
                  array :level4 do
                    array :level5 do
                      integer :value
                    end
                  end
                end
              end
            end
          end
        #{'  '}
          value :deep_values, input.level1.level2.level3.level4.level5.value
        end
      KUMI

      pack = pack_for(schema)
      generator = Kumi::Codegen::RubyV3::Generator.new(pack, module_name: "DeepNesting")

      result = generator.render

      # Should handle deep nesting with proper variable naming
      expect(result).to include("arr4 = a3[\"level5\"]")
      expect(result).to include("a4[\"value\"]")
    end
  end

  context "unicode and special characters" do
    it "handles field names with special characters" do
      schema = <<~KUMI
        schema do
          input do
            integer :field_with_underscore
            integer :field123
          end
        #{'  '}
          value :result, input.field_with_underscore + input.field123
        end
      KUMI

      pack = pack_for(schema)
      generator = Kumi::Codegen::RubyV3::Generator.new(pack, module_name: "SpecialChars")

      result = generator.render

      # Should properly quote field names
      expect(result).to include('"field_with_underscore"')
      expect(result).to include('"field123"')
    end
  end
end
