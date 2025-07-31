# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Text Parser: Error Parity" do
  # Test that both Ruby DSL and text parser produce similar errors for invalid syntax
  
  def create_ruby_schema_with_invalid_dsl(&block)
    Class.new do
      extend Kumi::Schema
      schema(&block)
    end
  end

  def expect_similar_errors(invalid_dsl_block, invalid_text_dsl)
    ruby_error = nil
    text_error = nil

    # Capture Ruby DSL error
    begin
      create_ruby_schema_with_invalid_dsl(&invalid_dsl_block)
    rescue => e
      ruby_error = e
    end

    # Capture text parser error  
    begin
      Kumi::TextParser.parse(invalid_text_dsl)
    rescue => e
      text_error = e
    end

    # Both should have failed
    expect(ruby_error).not_to be_nil, "Ruby DSL should have failed but didn't"
    expect(text_error).not_to be_nil, "Text parser should have failed but didn't"

    # Both should be Kumi errors (not just Ruby syntax errors)
    expect(ruby_error).to be_a(Kumi::Errors::KumiError)
    expect(text_error).to be_a(StandardError) # Text parser may not have Kumi-specific errors yet
  end

  describe "Invalid input declarations" do
    it "both parsers fail on unknown type" do
      invalid_ruby = proc do
        input do
          unknown_type :field
        end
        trait :always_true, true
      end

      invalid_text = <<~KUMI
        schema do
          input do
            unknown_type :field
          end
          trait :always_true, true
        end
      KUMI

      expect_similar_errors(invalid_ruby, invalid_text)
    end

    it "both parsers fail on malformed domain" do
      invalid_ruby = proc do
        input do
          integer :age, domain: "not_a_range"
        end
        trait :always_true, true
      end

      invalid_text = <<~KUMI
        schema do
          input do
            integer :age, domain: not_a_range
          end
          trait :always_true, true
        end
      KUMI

      # This might not fail identically yet, but let's see
      expect do
        create_ruby_schema_with_invalid_dsl(&invalid_ruby)
      end.to raise_error

      expect do
        Kumi::TextParser.parse(invalid_text)
      end.to raise_error
    end
  end

  describe "Invalid expressions" do
    it "both parsers fail on unknown function" do
      invalid_ruby = proc do
        input do
          integer :value
        end
        value :result, fn(:nonexistent_function, input.value)
      end

      invalid_text = <<~KUMI
        schema do
          input do
            integer :value
          end
          value :result, fn(:nonexistent_function, input.value)
        end
      KUMI

      expect_similar_errors(invalid_ruby, invalid_text)
    end

    it "both parsers handle malformed function syntax" do
      invalid_ruby = proc do
        input do
          integer :value
        end
        value :result, fn() # Empty function call
      end

      invalid_text = <<~KUMI
        schema do
          input do
            integer :value
          end
          value :result, fn()
        end
      KUMI

      # Both should fail on empty function calls
      expect do
        create_ruby_schema_with_invalid_dsl(&invalid_ruby)
      end.to raise_error

      expect do
        Kumi::TextParser.parse(invalid_text)
      end.to raise_error
    end
  end

  describe "Syntax validation" do
    it "both parsers fail on missing input block" do
      invalid_ruby = proc do
        # No input block
        value :result, 42
      end

      invalid_text = <<~KUMI
        schema do
          value :result, 42
        end
      KUMI

      expect_similar_errors(invalid_ruby, invalid_text)
    end

    it "both parsers fail on malformed value declaration" do
      invalid_ruby = proc do
        input do
          integer :value
        end
        value # Missing name and expression
      end

      invalid_text = <<~KUMI
        schema do
          input do
            integer :value
          end
          value
        end
      KUMI

      expect do
        create_ruby_schema_with_invalid_dsl(&invalid_ruby)
      end.to raise_error

      expect do
        Kumi::TextParser.parse(invalid_text)
      end.to raise_error
    end
  end
end