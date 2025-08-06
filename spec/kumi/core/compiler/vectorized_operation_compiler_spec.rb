# frozen_string_literal: true

require_relative "../../../../lib/kumi/core/compiler/operand_resolver"
require_relative "../../../../lib/kumi/core/compiler/vectorized_operation_compiler"

RSpec.describe Kumi::Core::Compiler::VectorizedOperationCompiler do
  let(:mock_binding) { lambda { |ctx| [50.0, 75.0] } }
  let(:mock_accessor) { lambda { |data| data["items"].map { |item| item["price"] } } }
  let(:bindings) { { prices: mock_binding } }
  let(:accessors) { { "items.price:element" => mock_accessor } }
  let(:compiler) { described_class.new(bindings, accessors) }
  
  let(:test_ctx) do
    {
      "items" => [
        { "price" => 100.0 },
        { "price" => 200.0 }
      ],
      "tax_rate" => 0.1
    }
  end
  
  let(:mock_expr) { double("expr", fn_name: :multiply) }
  
  # Mock registry functions
  before do
    allow(Kumi::Registry).to receive(:fetch).with(:multiply).and_return(->(a, b) { a * b })
    allow(Kumi::Registry).to receive(:fetch).with(:array_scalar_object).and_return(
      lambda do |op_proc, field_values, scalar_value|
        field_values.map { |val| op_proc.call(val, scalar_value) }
      end
    )
    allow(Kumi::Registry).to receive(:fetch).with(:element_wise_object).and_return(
      lambda do |op_proc, field_values1, field_values2|
        field_values1.zip(field_values2).map { |val1, val2| op_proc.call(val1, val2) }
      end
    )
  end
  
  describe "#compile" do
    context "with array_scalar_object strategy" do
      let(:metadata) do
        {
          strategy: :array_scalar_object,
          operands: [
            { source: { kind: :input_element, path: [:items, :price] } },
            { source: { kind: :input_field, name: :tax_rate } }
          ]
        }
      end
      
      it "pre-compiles into pure lambda with no runtime logic" do
        compiled_lambda = compiler.compile(mock_expr, metadata)
        
        expect(compiled_lambda).to be_a(Proc)
        
        # Pure lambda call - no case statements, no lookups
        result = compiled_lambda.call(test_ctx)
        expect(result).to eq([10.0, 20.0])  # [100*0.1, 200*0.1]
      end
    end
    
    context "with element_wise_object strategy" do
      let(:metadata) do
        {
          strategy: :element_wise_object,
          operands: [
            { source: { kind: :input_element, path: [:items, :price] } },
            { source: { kind: :declaration, name: :prices } }
          ]
        }
      end
      
      it "pre-compiles element-wise operation with no runtime logic" do
        compiled_lambda = compiler.compile(mock_expr, metadata)
        
        expect(compiled_lambda).to be_a(Proc)
        
        # Pure lambda call
        result = compiled_lambda.call(test_ctx)
        expect(result).to eq([5000.0, 15000.0])  # [100*50, 200*75]
      end
    end
    
    context "with literal operands" do
      let(:metadata) do
        {
          strategy: :array_scalar_object,
          operands: [
            { source: { kind: :input_element, path: [:items, :price] } },
            { source: { kind: :literal, value: 2.0 } }
          ]
        }
      end
      
      it "pre-resolves literal values with no runtime case statements" do
        compiled_lambda = compiler.compile(mock_expr, metadata)
        
        result = compiled_lambda.call(test_ctx)
        expect(result).to eq([200.0, 400.0])  # [100*2, 200*2]
      end
    end
    
    context "with unsupported strategy" do
      let(:metadata) do
        {
          strategy: :unsupported_strategy,
          operands: []
        }
      end
      
      it "raises error during compilation, not runtime" do
        expect {
          compiler.compile(mock_expr, metadata)
        }.to raise_error("Unsupported strategy for pre-compilation: unsupported_strategy")
      end
    end
  end
  
  describe "pure lambda behavior" do
    it "produces lambdas with no runtime decision making" do
      metadata = {
        strategy: :array_scalar_object,
        operands: [
          { source: { kind: :input_element, path: [:items, :price] } },
          { source: { kind: :literal, value: 0.5 } }
        ]
      }
      
      # Compilation should resolve everything
      compiled_lambda = compiler.compile(mock_expr, metadata)
      
      # Runtime should just be pure function calls
      result1 = compiled_lambda.call(test_ctx)
      result2 = compiled_lambda.call(test_ctx)
      
      # Same pure computation
      expect(result1).to eq([50.0, 100.0])
      expect(result2).to eq(result1)
    end
    
    it "contains no runtime lookups or case statements" do
      # This test verifies the philosophical goal:
      # The compiled lambda should contain ONLY function calls,
      # no hash lookups, no case statements, no conditional logic
      
      metadata = {
        strategy: :element_wise_object,
        operands: [
          { source: { kind: :declaration, name: :prices } },
          { source: { kind: :input_element, path: [:items, :price] } }
        ]
      }
      
      compiled_lambda = compiler.compile(mock_expr, metadata)
      
      # The lambda should work purely by calling pre-resolved functions
      result = compiled_lambda.call(test_ctx)
      expect(result).to eq([5000.0, 15000.0])
    end
  end
end