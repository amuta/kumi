# frozen_string_literal: true

require "spec_helper"
require "kumi/registry_v2/loader"
require "kumi/core/functions/type_rules"

RSpec.describe Kumi::RegistryV2::Loader do
  describe ".build_dtype_rule_from_yaml" do
    context "with structured dtype format" do
      it "builds same_as rule from structured hash" do
        yaml_spec = {
          "rule" => "same_as",
          "param" => "source_value"
        }
        rule = described_class.build_dtype_rule_from_yaml(yaml_spec)

        int_type = Kumi::Core::Types.scalar(:integer)
        result = rule.call({ source_value: int_type })

        expect(result).to eq(int_type)
      end

      it "builds promote rule from structured hash" do
        yaml_spec = {
          "rule" => "promote",
          "params" => %w[left_operand right_operand]
        }
        rule = described_class.build_dtype_rule_from_yaml(yaml_spec)

        int_type = Kumi::Core::Types.scalar(:integer)
        float_type = Kumi::Core::Types.scalar(:float)
        result = rule.call({ left_operand: int_type, right_operand: float_type })

        expect(result).to eq(float_type)
      end

      it "builds element_of rule from structured hash" do
        yaml_spec = {
          "rule" => "element_of",
          "param" => "source_value"
        }
        rule = described_class.build_dtype_rule_from_yaml(yaml_spec)

        int_type = Kumi::Core::Types.scalar(:integer)
        array_type = Kumi::Core::Types.array(int_type)
        result = rule.call({ source_value: array_type })

        expect(result).to eq(int_type)
      end

      it "builds unify rule from structured hash" do
        yaml_spec = {
          "rule" => "unify",
          "param1" => "left",
          "param2" => "right"
        }
        rule = described_class.build_dtype_rule_from_yaml(yaml_spec)

        int_type = Kumi::Core::Types.scalar(:integer)
        float_type = Kumi::Core::Types.scalar(:float)
        result = rule.call({ left: int_type, right: float_type })

        expect(result).to eq(float_type)
      end

      it "builds common_type rule from structured hash" do
        yaml_spec = {
          "rule" => "common_type",
          "param" => "elements"
        }
        rule = described_class.build_dtype_rule_from_yaml(yaml_spec)

        int_type = Kumi::Core::Types.scalar(:integer)
        float_type = Kumi::Core::Types.scalar(:float)
        result = rule.call({ elements: [int_type, float_type] })

        expect(result).to eq(float_type)
      end

      it "builds array rule with constant element type" do
        yaml_spec = {
          "rule" => "array",
          "element_type" => "integer"
        }
        rule = described_class.build_dtype_rule_from_yaml(yaml_spec)

        result = rule.call({})

        expect(result).to be_a(Kumi::Core::Types::ArrayType)
        expect(result.element_type.kind).to eq(:integer)
      end

      it "builds array rule with parameter reference" do
        yaml_spec = {
          "rule" => "array",
          "element_type_param" => "elem_type"
        }
        rule = described_class.build_dtype_rule_from_yaml(yaml_spec)

        int_type = Kumi::Core::Types.scalar(:integer)
        result = rule.call({ elem_type: int_type })

        expect(result).to be_a(Kumi::Core::Types::ArrayType)
        expect(result.element_type).to eq(int_type)
      end

      it "builds tuple rule with constant types" do
        yaml_spec = {
          "rule" => "tuple",
          "element_types" => %w[integer float]
        }
        rule = described_class.build_dtype_rule_from_yaml(yaml_spec)

        result = rule.call({})

        expect(result).to be_a(Kumi::Core::Types::TupleType)
        expect(result.element_types.map(&:kind)).to eq(%i[integer float])
      end

      it "builds scalar rule with kind" do
        yaml_spec = {
          "rule" => "scalar",
          "kind" => "float"
        }
        rule = described_class.build_dtype_rule_from_yaml(yaml_spec)

        result = rule.call({})

        expect(result).to be_a(Kumi::Core::Types::ScalarType)
        expect(result.kind).to eq(:float)
      end
    end

    context "with legacy string dtype format" do
      it "builds rule from legacy same_as string" do
        yaml_spec = "same_as(source_value)"
        rule = described_class.build_dtype_rule_from_yaml(yaml_spec)

        int_type = Kumi::Core::Types.scalar(:integer)
        result = rule.call({ source_value: int_type })

        expect(result).to eq(int_type)
      end

      it "builds rule from legacy promote string" do
        yaml_spec = "promote(left_operand,right_operand)"
        rule = described_class.build_dtype_rule_from_yaml(yaml_spec)

        int_type = Kumi::Core::Types.scalar(:integer)
        float_type = Kumi::Core::Types.scalar(:float)
        result = rule.call({ left_operand: int_type, right_operand: float_type })

        expect(result).to eq(float_type)
      end

      it "builds rule from legacy scalar string" do
        yaml_spec = "integer"
        rule = described_class.build_dtype_rule_from_yaml(yaml_spec)

        result = rule.call({})

        expect(result).to be_a(Kumi::Core::Types::ScalarType)
        expect(result.kind).to eq(:integer)
      end
    end

    context "validation and error handling" do
      it "raises error for unknown rule type" do
        yaml_spec = {
          "rule" => "unknown_rule",
          "param" => "x"
        }

        expect do
          described_class.build_dtype_rule_from_yaml(yaml_spec)
        end.to raise_error(/unknown dtype rule/)
      end

      it "raises error for missing required param in same_as" do
        yaml_spec = {
          "rule" => "same_as"
          # missing 'param'
        }

        expect do
          described_class.build_dtype_rule_from_yaml(yaml_spec)
        end.to raise_error(/same_as rule requires 'param'/)
      end

      it "raises error for missing required params in promote" do
        yaml_spec = {
          "rule" => "promote"
          # missing 'params'
        }

        expect do
          described_class.build_dtype_rule_from_yaml(yaml_spec)
        end.to raise_error(/promote rule requires 'params'/)
      end

      it "raises error for missing required kind in scalar" do
        yaml_spec = {
          "rule" => "scalar"
          # missing 'kind'
        }

        expect do
          described_class.build_dtype_rule_from_yaml(yaml_spec)
        end.to raise_error(/scalar rule requires 'kind'/)
      end

      it "raises error for scalar with invalid kind" do
        yaml_spec = {
          "rule" => "scalar",
          "kind" => "invalid_type"
        }

        expect do
          described_class.build_dtype_rule_from_yaml(yaml_spec)
        end.to raise_error(/unknown.*kind/)
      end
    end

    context "complex nested structures" do
      it "builds nested array rule" do
        yaml_spec = {
          "rule" => "array",
          "element_type" => {
            "rule" => "array",
            "element_type" => "string"
          }
        }
        rule = described_class.build_dtype_rule_from_yaml(yaml_spec)

        result = rule.call({})

        expect(result).to be_a(Kumi::Core::Types::ArrayType)
        inner = result.element_type
        expect(inner).to be_a(Kumi::Core::Types::ArrayType)
        expect(inner.element_type.kind).to eq(:string)
      end
    end
  end

  describe "backward compatibility" do
    it "loads functions with both string and structured dtype" do
      yaml_content = <<~YAML
        functions:
          - id: test.legacy
            kind: elementwise
            params: [{ name: x }]
            dtype: "same_as(x)"
            aliases: [legacy]

          - id: test.structured
            kind: elementwise
            params: [{ name: y }]
            dtype:
              rule: same_as
              param: y
            aliases: [structured]
      YAML

      # Write temp file
      require "tempfile"
      file = Tempfile.new(["test", ".yaml"])
      file.write(yaml_content)
      file.close

      # Load functions
      funcs = described_class.load_functions(File.dirname(file.path), Kumi::RegistryV2::Function)

      expect(funcs).to have_key("test.legacy")
      expect(funcs).to have_key("test.structured")

      # Both should have working dtype rules
      legacy_fn = funcs["test.legacy"]
      structured_fn = funcs["test.structured"]

      int_type = Kumi::Core::Types.scalar(:integer)

      legacy_result = legacy_fn.dtype_rule.call({ x: int_type })
      structured_result = structured_fn.dtype_rule.call({ y: int_type })

      expect(legacy_result).to eq(int_type)
      expect(structured_result).to eq(int_type)

      file.unlink
    end
  end
end
