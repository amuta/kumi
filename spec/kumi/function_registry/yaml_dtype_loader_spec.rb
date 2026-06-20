# frozen_string_literal: true

require "spec_helper"
require "kumi/function_registry/loader"

RSpec.describe Kumi::FunctionRegistry::Loader do
  let(:int_type) { Kumi::Core::Types.scalar(:integer) }
  let(:float_type) { Kumi::Core::Types.scalar(:float) }
  let(:decimal_type) { Kumi::Core::Types.scalar(:decimal) }

  describe ".build_dtype_rule_from_yaml" do
    context "with structured dtype rules" do
      it "builds a same_as rule" do
        rule = described_class.build_dtype_rule_from_yaml({ "rule" => "same_as", "param" => "source_value" })

        expect(rule.call({ source_value: int_type })).to eq(int_type)
      end

      it "builds a promote rule" do
        rule = described_class.build_dtype_rule_from_yaml({ "rule" => "promote", "params" => %w[left right] })

        expect(rule.call({ left: int_type, right: float_type })).to eq(float_type)
      end

      it "promotes decimal as the widest numeric kind" do
        rule = described_class.build_dtype_rule_from_yaml({ "rule" => "promote", "params" => %w[left right] })

        expect(rule.call({ left: decimal_type, right: int_type })).to eq(decimal_type)
      end

      it "builds an element_of rule" do
        rule = described_class.build_dtype_rule_from_yaml({ "rule" => "element_of", "param" => "source_value" })

        expect(rule.call({ source_value: Kumi::Core::Types.array(int_type) })).to eq(int_type)
      end

      it "builds a unify rule" do
        rule = described_class.build_dtype_rule_from_yaml({ "rule" => "unify", "param1" => "a", "param2" => "b" })

        expect(rule.call({ a: int_type, b: float_type })).to eq(float_type)
      end

      it "builds a scalar rule" do
        rule = described_class.build_dtype_rule_from_yaml({ "rule" => "scalar", "kind" => "float" })

        expect(rule.call({})).to eq(float_type)
      end
    end

    context "validation and error handling" do
      it "rejects a non-hash spec" do
        expect { described_class.build_dtype_rule_from_yaml("same_as(x)") }
          .to raise_error(/dtype spec must be a hash/)
      end

      it "rejects an unknown rule type" do
        expect { described_class.build_dtype_rule_from_yaml({ "rule" => "unknown_rule", "param" => "x" }) }
          .to raise_error(/unknown dtype rule/)
      end

      it "requires the param key for same_as" do
        expect { described_class.build_dtype_rule_from_yaml({ "rule" => "same_as" }) }
          .to raise_error(/same_as rule requires 'param'/)
      end

      it "requires the params key for promote" do
        expect { described_class.build_dtype_rule_from_yaml({ "rule" => "promote" }) }
          .to raise_error(/promote rule requires 'params'/)
      end

      it "requires the kind key for scalar" do
        expect { described_class.build_dtype_rule_from_yaml({ "rule" => "scalar" }) }
          .to raise_error(/scalar rule requires 'kind'/)
      end

      it "rejects an unknown scalar kind" do
        expect { described_class.build_dtype_rule_from_yaml({ "rule" => "scalar", "kind" => "invalid_type" }) }
          .to raise_error(/unknown.*kind/)
      end
    end
  end

  describe ".load_functions" do
    it "loads functions and compiles their dtype rules" do
      yaml_content = <<~YAML
        functions:
          - id: test.same
            kind: elementwise
            params: [{ name: x }]
            dtype:
              rule: same_as
              param: x
            aliases: [same]

          - id: test.scalar
            kind: elementwise
            params: [{ name: y }]
            dtype:
              rule: scalar
              kind: float
            aliases: [scalarfn]
      YAML

      # load_functions globs the directory recursively, so the fixture must live
      # in its OWN isolated dir to avoid picking up unrelated YAML.
      require "tmpdir"
      Dir.mktmpdir("kumi-loader-spec") do |dir|
        File.write(File.join(dir, "functions.yaml"), yaml_content)

        funcs = described_class.load_functions(dir, Kumi::FunctionRegistry::Function)

        expect(funcs.keys).to contain_exactly("test.same", "test.scalar")
        expect(funcs["test.same"].dtype_rule.call({ x: int_type })).to eq(int_type)
        expect(funcs["test.scalar"].dtype_rule.call({ y: int_type })).to eq(float_type)
      end
    end
  end
end
