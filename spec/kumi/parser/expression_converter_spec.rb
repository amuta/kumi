# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kumi::RubyParser::ExpressionConverter do
  let(:context) { double("context", current_location: location) }
  let(:location) { double("location", file: "test.rb", line: 10, column: 5) }
  let(:converter) { described_class.new(context) }

  describe "#ensure_syntax" do
    context "with literal types" do
      it "converts integers to literal nodes" do
        result = converter.ensure_syntax(42)

        expect(result).to be_a(Kumi::Syntax::Literal)
        expect(result.value).to eq(42)
        expect(result.loc).to eq(location)
      end

      it "converts strings to literal nodes" do
        result = converter.ensure_syntax("hello")

        expect(result).to be_a(Kumi::Syntax::Literal)
        expect(result.value).to eq("hello")
        expect(result.loc).to eq(location)
      end

      it "converts floats to literal nodes" do
        result = converter.ensure_syntax(3.14)

        expect(result).to be_a(Kumi::Syntax::Literal)
        expect(result.value).to eq(3.14)
        expect(result.loc).to eq(location)
      end

      it "converts booleans to literal nodes" do
        true_result = converter.ensure_syntax(true)
        false_result = converter.ensure_syntax(false)

        expect(true_result).to be_a(Kumi::Syntax::Literal)
        expect(true_result.value).to be(true)

        expect(false_result).to be_a(Kumi::Syntax::Literal)
        expect(false_result.value).to be(false)
      end

      it "converts symbols to literal nodes" do
        result = converter.ensure_syntax(:test_symbol)

        expect(result).to be_a(Kumi::Syntax::Literal)
        expect(result.value).to eq(:test_symbol)
        expect(result.loc).to eq(location)
      end

      it "converts regexes to literal nodes" do
        regex = /test_pattern/i
        result = converter.ensure_syntax(regex)

        expect(result).to be_a(Kumi::Syntax::Literal)
        expect(result.value).to eq(regex)
        expect(result.loc).to eq(location)
      end
    end

    context "with array types" do
      it "converts arrays to list expressions" do
        result = converter.ensure_syntax([1, "hello", true])

        expect(result).to be_a(Kumi::Syntax::ArrayExpression)
        expect(result.elements.size).to eq(3)

        expect(result.elements[0]).to be_a(Kumi::Syntax::Literal)
        expect(result.elements[0].value).to eq(1)

        expect(result.elements[1]).to be_a(Kumi::Syntax::Literal)
        expect(result.elements[1].value).to eq("hello")

        expect(result.elements[2]).to be_a(Kumi::Syntax::Literal)
        expect(result.elements[2].value).to be(true)
      end

      it "handles nested arrays" do
        result = converter.ensure_syntax([1, [2, 3], 4])

        expect(result).to be_a(Kumi::Syntax::ArrayExpression)
        expect(result.elements.size).to eq(3)

        nested_list = result.elements[1]
        expect(nested_list).to be_a(Kumi::Syntax::ArrayExpression)
        expect(nested_list.elements.size).to eq(2)
      end

      it "handles empty arrays" do
        result = converter.ensure_syntax([])

        expect(result).to be_a(Kumi::Syntax::ArrayExpression)
        expect(result.elements).to be_empty
      end
    end

    context "with existing syntax nodes" do
      it "returns syntax nodes unchanged" do
        existing_node = Kumi::Syntax::Literal.new("test")
        result = converter.ensure_syntax(existing_node)

        expect(result).to be(existing_node)
      end
    end

    context "with custom objects" do
      let(:custom_object) { double("custom_object") }
      let(:ast_node) { Kumi::Syntax::Literal.new("converted") }

      it "converts objects that respond to to_ast_node" do
        allow(custom_object).to receive(:respond_to?).with(:to_ast_node).and_return(true)
        allow(custom_object).to receive(:to_ast_node).and_return(ast_node)

        result = converter.ensure_syntax(custom_object)

        expect(result).to eq(ast_node)
      end

      it "raises error for objects that don't respond to to_ast_node" do
        allow(custom_object).to receive(:respond_to?).with(:to_ast_node).and_return(false)

        expect do
          converter.ensure_syntax(custom_object)
        end.to raise_error(Kumi::Errors::SyntaxError, /Cannot convert/)
      end
    end
  end

  describe "#ref" do
    context "with valid symbol names" do
      it "creates binding nodes with correct name and location" do
        result = converter.ref(:test_name)

        expect(result).to be_a(Kumi::Syntax::DeclarationReference)
        expect(result.name).to eq(:test_name)
        expect(result.loc).to eq(location)
      end
    end

    context "with invalid names" do
      it "raises error for non-symbol names" do
        expect do
          converter.ref("string_name")
        end.to raise_error(Kumi::Errors::SyntaxError, /Reference name must be a symbol/)
      end

      it "raises error for nil names" do
        expect do
          converter.ref(nil)
        end.to raise_error(Kumi::Errors::SyntaxError, /Reference name must be a symbol/)
      end

      it "raises error for numeric names" do
        expect do
          converter.ref(123)
        end.to raise_error(Kumi::Errors::SyntaxError, /Reference name must be a symbol/)
      end
    end
  end

  describe "#literal" do
    it "creates literal nodes with correct value and location" do
      result = converter.literal("test_value")

      expect(result).to be_a(Kumi::Syntax::Literal)
      expect(result.value).to eq("test_value")
      expect(result.loc).to eq(location)
    end

    it "works with any value type" do
      values = [42, "string", true, false, nil, :symbol, /regex/]

      values.each do |value|
        result = converter.literal(value)

        expect(result).to be_a(Kumi::Syntax::Literal)
        expect(result.value).to eq(value)
      end
    end
  end

  describe "#fn" do
    context "with valid function calls" do
      it "creates call expressions with no arguments" do
        result = converter.fn(:test_fn)

        expect(result).to be_a(Kumi::Syntax::CallExpression)
        expect(result.fn_name).to eq(:test_fn)
        expect(result.args).to be_empty
        expect(result.loc).to eq(location)
      end

      it "creates call expressions with single argument" do
        result = converter.fn(:test_fn, 42)

        expect(result).to be_a(Kumi::Syntax::CallExpression)
        expect(result.fn_name).to eq(:test_fn)
        expect(result.args.size).to eq(1)

        arg = result.args.first
        expect(arg).to be_a(Kumi::Syntax::Literal)
        expect(arg.value).to eq(42)
      end

      it "creates call expressions with multiple arguments" do
        result = converter.fn(:add, 10, 20, 30)

        expect(result).to be_a(Kumi::Syntax::CallExpression)
        expect(result.fn_name).to eq(:add)
        expect(result.args.size).to eq(3)

        expect(result.args[0].value).to eq(10)
        expect(result.args[1].value).to eq(20)
        expect(result.args[2].value).to eq(30)
      end

      it "converts arguments through ensure_syntax" do
        result = converter.fn(:test_fn, [1, 2], "string", true)

        expect(result.args[0]).to be_a(Kumi::Syntax::ArrayExpression)
        expect(result.args[1]).to be_a(Kumi::Syntax::Literal)
        expect(result.args[2]).to be_a(Kumi::Syntax::Literal)
      end
    end

    context "with invalid function names" do
      it "raises error for string function names" do
        expect do
          converter.fn("string_fn", 42)
        end.to raise_error(Kumi::Errors::SyntaxError, /Function name must be a symbol/)
      end

      it "raises error for nil function names" do
        expect do
          converter.fn(nil, 42)
        end.to raise_error(Kumi::Errors::SyntaxError, /Function name must be a symbol/)
      end

      it "raises error for numeric function names" do
        expect do
          converter.fn(123, 42)
        end.to raise_error(Kumi::Errors::SyntaxError, /Function name must be a symbol/)
      end
    end
  end

  describe "#input" do
    it "creates input proxy with context" do
      result = converter.input

      expect(result).to be_a(Kumi::RubyParser::InputProxy)
      # NOTE: We can't easily test the internal context without exposing it
      # This test verifies the type and that it doesn't raise an error
    end
  end

  describe "#raise_error" do
    it "raises syntax error with provided message and location" do
      test_location = double("test_location", file: "test.rb", line: 5, column: 10)

      expect do
        converter.raise_error("Test error message", test_location)
      end.to raise_error(Kumi::Errors::SyntaxError) do |error|
        expect(error.message).to include("Test error message")
      end
    end
  end

  describe "private methods" do
    describe "#validate_reference_name" do
      it "accepts valid symbol names" do
        # This shouldn't raise an error
        expect { converter.ref(:valid_name) }.not_to raise_error
      end

      it "rejects non-symbol names with descriptive error" do
        error_message = /Reference name must be a symbol, got String/

        expect do
          converter.ref("invalid")
        end.to raise_error(Kumi::Errors::SyntaxError, error_message)
      end
    end

    describe "#validate_function_name" do
      it "accepts valid symbol names" do
        expect { converter.fn(:valid_fn) }.not_to raise_error
      end

      it "rejects non-symbol names with descriptive error" do
        error_message = /Function name must be a symbol, got String/

        expect do
          converter.fn("invalid")
        end.to raise_error(Kumi::Errors::SyntaxError, error_message)
      end
    end

    describe "error message quality" do
      it "includes object class and value in invalid expression errors" do
        unsupported_object = Object.new

        expect do
          converter.ensure_syntax(unsupported_object)
        end.to raise_error(Kumi::Errors::SyntaxError) do |error|
          expect(error.message).to include("Cannot convert Object to AST node")
          expect(error.message).to include("Value:")
        end
      end
    end
  end

  describe "integration scenarios" do
    it "handles complex nested expressions" do
      # Simulate: fn(:add, [1, 2], ref(:other_value))
      nested_array = [1, 2]

      result = converter.fn(:add, nested_array, converter.ref(:other_value))

      expect(result).to be_a(Kumi::Syntax::CallExpression)
      expect(result.fn_name).to eq(:add)
      expect(result.args.size).to eq(2)

      # First arg should be converted array
      expect(result.args[0]).to be_a(Kumi::Syntax::ArrayExpression)
      expect(result.args[0].elements.size).to eq(2)

      # Second arg should be reference
      expect(result.args[1]).to be_a(Kumi::Syntax::DeclarationReference)
      expect(result.args[1].name).to eq(:other_value)
    end

    it "preserves location information across conversions" do
      result = converter.fn(:test, [1, 2], converter.literal("hello"))

      expect(result.loc).to eq(location)

      # Arguments should also have location
      expect(result.args[0].loc).to eq(location)  # List expression
      expect(result.args[1].loc).to eq(location)  # Literal
    end
  end
end
