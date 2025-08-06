# frozen_string_literal: true

require_relative "../../../../lib/kumi/core/compiler/registry_argument_builder"

RSpec.describe Kumi::Core::Compiler::RegistryArgumentBuilder do
  let(:mock_expr) { double("expr", fn_name: :multiply) }
  let(:mock_ctx) { double("ctx", ctx: test_data) }
  let(:test_data) do
    {
      "items" => [
        { "price" => 100.0 },
        { "price" => 200.0 }
      ],
      "tax_rate" => 0.1
    }
  end
  let(:bindings) { {} }
  let(:accessors) do
    {
      "items.price:element" => lambda { |data| data["items"].map { |item| item["price"] } }
    }
  end
  
  describe ".build_argument_extractor" do
    context "for array_scalar_object strategy" do
      let(:extractor) { described_class.build_argument_extractor(:array_scalar_object) }
      let(:operands) do
        [
          {
            source: {
              kind: :input_element,
              path: [:items, :price]
            }
          },
          {
            source: {
              kind: :input_field,
              name: :tax_rate
            }
          }
        ]
      end
      
      before do
        # Mock the registry fetch
        allow(Kumi::Registry).to receive(:fetch).with(:multiply).and_return(->(a, b) { a * b })
      end
      
      it "returns a proc that builds correct arguments" do
        expect(extractor).to be_a(Proc)
        
        # Call the extractor
        args = extractor.call(mock_expr, operands, mock_ctx, bindings, accessors)
        
        # Verify arguments structure
        expect(args.length).to eq(3)
        expect(args[0]).to be_a(Proc)  # operation_proc
        expect(args[1]).to eq([100.0, 200.0])  # array values
        expect(args[2]).to eq(0.1)  # scalar value
      end
      
      it "produces arguments that work with registry function" do
        args = extractor.call(mock_expr, operands, mock_ctx, bindings, accessors)
        op_proc, array_vals, scalar_val = args
        
        # Test that the arguments work with array_scalar_object pattern
        result = array_vals.map { |val| op_proc.call(val, scalar_val) }
        expect(result).to eq([10.0, 20.0])  # 100*0.1, 200*0.1
      end
    end
    
    context "for element_wise_object strategy" do
      let(:extractor) { described_class.build_argument_extractor(:element_wise_object) }
      let(:operands) do
        [
          {
            source: {
              kind: :input_element,
              path: [:items, :price]
            }
          },
          {
            source: {
              kind: :input_element,
              path: [:items, :price]  # Same for simplicity
            }
          }
        ]
      end
      
      before do
        allow(Kumi::Registry).to receive(:fetch).with(:multiply).and_return(->(a, b) { a * b })
      end
      
      it "builds arguments for two arrays" do
        args = extractor.call(mock_expr, operands, mock_ctx, bindings, accessors)
        
        expect(args.length).to eq(3)
        expect(args[0]).to be_a(Proc)  # operation_proc
        expect(args[1]).to eq([100.0, 200.0])  # first array
        expect(args[2]).to eq([100.0, 200.0])  # second array
      end
    end
    
    context "with unknown strategy" do
      it "raises an error" do
        expect {
          described_class.build_argument_extractor(:unknown_strategy)
        }.to raise_error("Unknown strategy: unknown_strategy")
      end
    end
  end
end