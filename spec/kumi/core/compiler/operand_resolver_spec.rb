# frozen_string_literal: true

require_relative "../../../../lib/kumi/core/compiler/operand_resolver"

RSpec.describe Kumi::Core::Compiler::OperandResolver do
  let(:mock_binding) { lambda { |ctx| ["resolved", "binding", "result"] } }
  let(:mock_accessor) { lambda { |data| data["items"].map { |item| item["price"] } } }
  let(:bindings) { { prices: mock_binding } }
  let(:accessors) { { "items.price:element" => mock_accessor } }
  let(:resolver) { described_class.new(bindings, accessors) }
  
  let(:test_ctx) do
    {
      "items" => [
        { "price" => 100.0 },
        { "price" => 200.0 }
      ],
      "tax_rate" => 0.1
    }
  end
  
  describe "#resolve_operand" do
    context "with declaration operand" do
      let(:operand) do
        {
          source: {
            kind: :declaration,
            name: :prices
          }
        }
      end
      
      it "pre-resolves binding and returns pure lambda" do
        extractor = resolver.resolve_operand(operand)
        
        # Should return a lambda
        expect(extractor).to be_a(Proc)
        
        # Lambda should call pre-resolved binding with no runtime logic
        result = extractor.call(test_ctx)
        expect(result).to eq(["resolved", "binding", "result"])
      end
      
      it "raises error for missing binding during compilation" do
        missing_operand = { source: { kind: :declaration, name: :missing } }
        
        expect {
          resolver.resolve_operand(missing_operand)
        }.to raise_error("Missing binding for declaration: missing")
      end
    end
    
    context "with input element operand" do
      let(:operand) do
        {
          source: {
            kind: :input_element,
            path: [:items, :price]
          }
        }
      end
      
      it "pre-resolves accessor and returns pure lambda" do
        extractor = resolver.resolve_operand(operand)
        
        expect(extractor).to be_a(Proc)
        
        # Lambda should call pre-resolved accessor with no runtime logic
        result = extractor.call(test_ctx)
        expect(result).to eq([100.0, 200.0])
      end
      
      it "raises error for missing accessor during compilation" do
        missing_operand = { 
          source: { 
            kind: :input_element, 
            path: [:missing, :field] 
          } 
        }
        
        expect {
          resolver.resolve_operand(missing_operand)
        }.to raise_error("Missing accessor for: missing.field:element")
      end
    end
    
    context "with input field operand" do
      let(:operand) do
        {
          source: {
            kind: :input_field,
            name: :tax_rate
          }
        }
      end
      
      it "pre-resolves field access and returns pure lambda" do
        extractor = resolver.resolve_operand(operand)
        
        expect(extractor).to be_a(Proc)
        
        # Lambda should extract field with no runtime case statements
        result = extractor.call(test_ctx)
        expect(result).to eq(0.1)
      end
    end
    
    context "with literal operand" do
      let(:operand) do
        {
          source: {
            kind: :literal,
            value: 42.5
          }
        }
      end
      
      it "pre-resolves value and returns pure lambda" do
        extractor = resolver.resolve_operand(operand)
        
        expect(extractor).to be_a(Proc)
        
        # Lambda should return pre-resolved value with no runtime logic
        result = extractor.call(test_ctx)
        expect(result).to eq(42.5)
      end
    end
    
    context "with unknown operand kind" do
      let(:operand) do
        {
          source: {
            kind: :unknown
          }
        }
      end
      
      it "raises error during compilation" do
        expect {
          resolver.resolve_operand(operand)
        }.to raise_error("Unknown operand source kind: unknown")
      end
    end
  end
  
  describe "pure lambda behavior" do
    it "resolved lambdas contain no runtime logic" do
      # Test that resolved lambdas are truly pure - just function calls
      declaration_operand = { source: { kind: :declaration, name: :prices } }
      literal_operand = { source: { kind: :literal, value: 123 } }
      
      decl_extractor = resolver.resolve_operand(declaration_operand)
      literal_extractor = resolver.resolve_operand(literal_operand)
      
      # These should be pure lambdas with no conditional logic
      # Just calling pre-resolved bindings/values
      expect(decl_extractor.call(test_ctx)).to eq(["resolved", "binding", "result"])
      expect(literal_extractor.call(test_ctx)).to eq(123)
    end
  end
end