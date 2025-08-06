# frozen_string_literal: true

# These files are now provided, so we require them.
require_relative "../../../lib/kumi/core/ruby_compiler"
require_relative "../../../lib/kumi/core/compiler/operand_resolver"

# Mock the components that are not under test.
module Kumi::Core::Compiler
  class AccessorPlanner; def self.plan(meta) = {}; end

  class AccessorBuilder
    def self.build(plans)
      @plans = plans
    end

    class << self
      attr_reader :plans
    end
  end
end

# Mock the registry.
Kumi::Registry = Class.new do
  def self.fetch(name)
    @stubs ||= {}
    @stubs[name]
  end

  class << self
    attr_reader :stubs
  end
end
Kumi::Core::CompiledSchema = Struct.new(:bindings)

RSpec.describe Kumi::Core::RubyCompiler do
  describe "#compile a vectorized operation" do
    # ARRANGE
    let(:schema) do
      double("Schema", attributes: [
               double("ValueDeclaration", name: :prices_with_tax, expression: double("CallExpression", fn_name: :*))
             ], traits: [], inputs: [])
    end

    let(:detector_metadata) do
      {
        prices_with_tax: {
          operation_type: :vectorized,
          strategy: :array_scalar_object,
          operands: [
            { source: { kind: :input_element, path: %i[items price] } },
            { source: { kind: :input_field, name: :tax_rate } }
          ]
        }
      }
    end

    let(:analysis_result) do
      double(
        "AnalysisResult",
        topo_order: [:prices_with_tax],
        state: {
          detector_metadata: detector_metadata,
          inputs: {} # Accessors are mocked, so this isn't strictly needed
        }
      )
    end

    let(:test_data_context) do
      {
        "items" => [{ "price" => 100.0 }, { "price" => 200.0 }],
        "tax_rate" => 1.1
      }
    end

    before do
      # Mock what AccessorBuilder would create. The OperandResolver will use this.
      allow(Kumi::Core::Compiler::AccessorBuilder).to receive(:build).and_return(
        "items.price:element" => ->(ctx) { ctx["items"].map { |i| i["price"] } }
      )

      # Stub the registry calls to isolate the compiler's logic.
      Kumi::Registry.stubs[:*] = ->(a, b) { a * b }
      Kumi::Registry.stubs[:array_scalar_object] = lambda do |op_proc, array, scalar|
        array.map { |el| op_proc.call(el, scalar) }
      end
    end

    it "compiles a pure lambda that correctly builds arguments and executes the operation" do
      # ACT
      compiler = described_class.new(schema, analysis_result)
      compiled_schema = compiler.compile
      calculator_lambda = compiled_schema.bindings[:prices_with_tax]
      result = calculator_lambda.call(test_data_context)

      # ASSERT
      expect(result).to eq([110.0, 220.0])
    end
  end
end
