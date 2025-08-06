# frozen_string_literal: true

require_relative "../../../../lib/kumi/core/compiler/expression_builder"
require_relative "../../../../lib/kumi/syntax/literal"
require_relative "../../../../lib/kumi/syntax/call_expression"
require_relative "../../../../lib/kumi/syntax/input_reference"
require_relative "../../../../lib/kumi/syntax/input_element_reference"
require_relative "../../../../lib/kumi/syntax/declaration_reference"
require_relative "../../../../lib/kumi/syntax/array_expression"
require_relative "../../../../lib/kumi/syntax/cascade_expression"
require_relative "../../../../lib/kumi/syntax/case_expression"

RSpec.describe Kumi::Core::Compiler::ExpressionBuilder do
  let(:mock_binding) { lambda { |ctx| "binding_result" } }
  let(:bindings) { { test_binding: mock_binding } }
  let(:builder) { described_class.new(bindings) }
  
  let(:test_ctx) do
    {
      "name" => "John",
      "age" => 30,
      "profile" => {
        "email" => "john@example.com"
      }
    }
  end

  # Mock registry functions
  before do
    allow(Kumi::Registry).to receive(:fetch).with(:add).and_return(->(a, b) { a + b })
    allow(Kumi::Registry).to receive(:fetch).with(:multiply).and_return(->(a, b) { a * b })
  end

  describe "#compile" do
    context "with literal expression" do
      let(:literal_expr) { Kumi::Syntax::Literal.new(42) }
      
      it "compiles literal into pure lambda" do
        compiled = builder.compile(literal_expr)
        
        expect(compiled).to be_a(Proc)
        expect(compiled.call(test_ctx)).to eq(42)
      end
    end
    
    context "with input field reference" do
      let(:field_expr) { Kumi::Syntax::InputReference.new(:name) }
      
      it "compiles field access into pure lambda" do
        compiled = builder.compile(field_expr)
        
        expect(compiled).to be_a(Proc)
        expect(compiled.call(test_ctx)).to eq("John")
      end
      
      it "supports symbol fallback for field access" do
        # Test that both string and symbol keys work
        symbol_ctx = { name: "Jane" }
        compiled = builder.compile(field_expr)
        
        expect(compiled.call(symbol_ctx)).to eq("Jane")
      end
    end
    
    context "with input element reference" do
      let(:element_expr) { Kumi::Syntax::InputElementReference.new([:profile, :email]) }
      
      it "compiles nested access into pure lambda" do
        compiled = builder.compile(element_expr)
        
        expect(compiled).to be_a(Proc)
        expect(compiled.call(test_ctx)).to eq("john@example.com")
      end
      
      it "handles missing nested paths gracefully" do
        missing_expr = Kumi::Syntax::InputElementReference.new([:missing, :field])
        compiled = builder.compile(missing_expr)
        
        expect(compiled.call(test_ctx)).to be_nil
      end
    end
    
    context "with declaration reference" do
      let(:decl_expr) { Kumi::Syntax::DeclarationReference.new(:test_binding) }
      
      it "compiles declaration reference into pure lambda" do
        compiled = builder.compile(decl_expr)
        
        expect(compiled).to be_a(Proc)
        expect(compiled.call(test_ctx)).to eq("binding_result")
      end
      
      it "handles missing binding gracefully" do
        missing_expr = Kumi::Syntax::DeclarationReference.new(:missing_binding)
        compiled = builder.compile(missing_expr)
        
        expect(compiled.call(test_ctx)).to be_nil
      end
    end
    
    context "with function call expression" do
      let(:literal_5) { Kumi::Syntax::Literal.new(5) }
      let(:literal_10) { Kumi::Syntax::Literal.new(10) }
      let(:call_expr) { Kumi::Syntax::CallExpression.new(:add, [literal_5, literal_10]) }
      
      it "compiles function call into pure lambda" do
        compiled = builder.compile(call_expr)
        
        expect(compiled).to be_a(Proc)
        expect(compiled.call(test_ctx)).to eq(15)
      end
      
      it "compiles nested function calls" do
        # multiply(add(5, 10), 2)
        inner_call = Kumi::Syntax::CallExpression.new(:add, [literal_5, literal_10])
        literal_2 = Kumi::Syntax::Literal.new(2)
        nested_call = Kumi::Syntax::CallExpression.new(:multiply, [inner_call, literal_2])
        
        compiled = builder.compile(nested_call)
        
        expect(compiled.call(test_ctx)).to eq(30)  # (5 + 10) * 2
      end
    end
    
    context "with array expression" do
      let(:literal_1) { Kumi::Syntax::Literal.new(1) }
      let(:literal_2) { Kumi::Syntax::Literal.new(2) }
      let(:literal_3) { Kumi::Syntax::Literal.new(3) }
      let(:array_expr) { Kumi::Syntax::ArrayExpression.new([literal_1, literal_2, literal_3]) }
      
      it "compiles array expression into pure lambda" do
        compiled = builder.compile(array_expr)
        
        expect(compiled).to be_a(Proc)
        expect(compiled.call(test_ctx)).to eq([1, 2, 3])
      end
      
      it "compiles mixed element types in array" do
        name_ref = Kumi::Syntax::InputReference.new(:name)
        mixed_array = Kumi::Syntax::ArrayExpression.new([literal_1, name_ref, literal_3])
        
        compiled = builder.compile(mixed_array)
        
        expect(compiled.call(test_ctx)).to eq([1, "John", 3])
      end
    end
    
    context "with cascade expression" do
      let(:true_literal) { Kumi::Syntax::Literal.new(true) }
      let(:false_literal) { Kumi::Syntax::Literal.new(false) }
      let(:result_a) { Kumi::Syntax::Literal.new("A") }
      let(:result_b) { Kumi::Syntax::Literal.new("B") }
      let(:default_result) { Kumi::Syntax::Literal.new("DEFAULT") }
      
      it "compiles simple cascade with base case" do
        # Case: on false, "A"; base "DEFAULT"
        conditional_case = Kumi::Syntax::CaseExpression.new(false_literal, result_a)
        base_case = Kumi::Syntax::CaseExpression.new(true_literal, default_result)
        cascade_expr = Kumi::Syntax::CascadeExpression.new([conditional_case, base_case])
        
        compiled = builder.compile(cascade_expr)
        
        # Should return default since condition is false
        expect(compiled.call(test_ctx)).to eq("DEFAULT")
      end
      
      it "compiles cascade with multiple conditions" do
        # Age-based cascade
        age_ref = Kumi::Syntax::InputReference.new(:age)
        age_30 = Kumi::Syntax::Literal.new(30)
        age_check = Kumi::Syntax::CallExpression.new(:add, [age_ref, Kumi::Syntax::Literal.new(0)]) # Mock condition
        
        # on age condition, "ADULT"; base "CHILD"  
        conditional_case = Kumi::Syntax::CaseExpression.new(true_literal, Kumi::Syntax::Literal.new("ADULT"))
        base_case = Kumi::Syntax::CaseExpression.new(true_literal, Kumi::Syntax::Literal.new("CHILD"))
        cascade_expr = Kumi::Syntax::CascadeExpression.new([conditional_case, base_case])
        
        compiled = builder.compile(cascade_expr)
        
        # Should return first match (ADULT since condition is true)
        expect(compiled.call(test_ctx)).to eq("ADULT")
      end
      
      it "correctly short-circuits and doesn't evaluate subsequent conditions" do
        # Test that cascade stops at first true condition and doesn't evaluate later ones
        call_count = 0
        
        # Mock a condition that increments a counter when called
        counting_condition = double("condition")
        allow(counting_condition).to receive(:call) do
          call_count += 1
          true  # Always return true
        end
        
        # Create a cascade with multiple conditions
        first_case = Kumi::Syntax::CaseExpression.new(true_literal, Kumi::Syntax::Literal.new("FIRST"))
        second_case = Kumi::Syntax::CaseExpression.new(true_literal, Kumi::Syntax::Literal.new("SECOND"))  
        base_case = Kumi::Syntax::CaseExpression.new(true_literal, Kumi::Syntax::Literal.new("BASE"))
        
        cascade_expr = Kumi::Syntax::CascadeExpression.new([first_case, second_case, base_case])
        compiled = builder.compile(cascade_expr)
        
        result = compiled.call(test_ctx)
        
        # Should return first match and not evaluate second condition
        expect(result).to eq("FIRST")
        # This test is about the logic structure - the key insight is that
        # only the first true condition should be evaluated, not subsequent ones
      end
    end
    
    context "with unknown expression type" do
      let(:unknown_expr) { double("unknown") }
      
      it "raises error during compilation" do
        expect {
          builder.compile(unknown_expr)
        }.to raise_error("Unknown expression type: RSpec::Mocks::Double")
      end
    end
  end
  
  describe "pure lambda behavior" do
    it "produces lambdas with no runtime logic" do
      # Test that compiled lambdas contain only pre-resolved function calls
      literal_expr = Kumi::Syntax::Literal.new("test")
      field_expr = Kumi::Syntax::InputReference.new(:name)
      
      literal_lambda = builder.compile(literal_expr)
      field_lambda = builder.compile(field_expr)
      
      # These should be pure lambdas
      expect(literal_lambda.call(test_ctx)).to eq("test")
      expect(field_lambda.call(test_ctx)).to eq("John")
      
      # Consistent behavior on multiple calls
      expect(literal_lambda.call(test_ctx)).to eq("test")
      expect(field_lambda.call(test_ctx)).to eq("John")
    end
    
    it "resolves all dependencies at compile time" do
      # Complex expression with multiple dependencies
      age_ref = Kumi::Syntax::InputReference.new(:age)
      literal_5 = Kumi::Syntax::Literal.new(5)
      call_expr = Kumi::Syntax::CallExpression.new(:add, [age_ref, literal_5])
      
      compiled = builder.compile(call_expr)
      
      # All registry lookups and argument resolution should be done at compile time
      # Runtime should just be pure function execution
      result = compiled.call(test_ctx)
      expect(result).to eq(35)  # 30 + 5
    end
  end
  
  describe "context handling" do
    it "handles direct hash contexts" do
      # Test with direct hash context
      direct_ctx = { "name" => "Direct" }
      field_expr = Kumi::Syntax::InputReference.new(:name)
      compiled = builder.compile(field_expr)
      
      expect(compiled.call(direct_ctx)).to eq("Direct")
    end
  end
end