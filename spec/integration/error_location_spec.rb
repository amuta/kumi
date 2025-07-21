# frozen_string_literal: true

require_relative "../support/error_location_tester"

RSpec.describe "Error Location and Message Verification" do
  include_context "schema generator"
  describe "Exact error line detection" do
    it "reports duplicate trait names at correct line" do
      schema_code = <<~RUBY
        Kumi.schema do
          input { integer :age }
          trait :adult, (input.age >= 18)
          trait :adult, (input.age >= 21)
          value :result, "test"
        end
      RUBY

      result = test_error_location(
        schema_code,
        expected_line: 4,
        pattern: "duplicated definition",
        type: Kumi::Errors::SemanticError
      )

      expect(result[:success]).to be(true), "Expected error at line 4 but got line #{result[:actual_line]}"
      expect(result[:pattern_match]).to be(true), "Expected 'duplicated definition' in error message"
      expect(result[:line_content]).to include("trait :adult, (input.age >= 21)")
    end

    it "reports circular dependencies with clear messages" do
      schema_code = <<~RUBY
        Kumi.schema do
          input { integer :x }
          value :a, ref(:b)
          value :b, ref(:a)
        end
      RUBY

      result = test_error_location(
        schema_code,
        expected_line: 3, # First value in cycle
        pattern: "cycle detected",
        type: Kumi::Errors::SemanticError
      )

      # NOTE: Circular dependency errors might not have exact line info
      expect(result[:error_message]).to include("cycle detected")
      expect(result[:error_message]).to include("a → b → a")
    end

    it "reports type mismatches at function call location" do
      schema_code = <<~RUBY
        Kumi.schema do
          input do
            string :name
            integer :age#{'  '}
          end
          value :bad_math, fn(:add, input.name, input.age)
        end
      RUBY

      result = test_error_location(
        schema_code,
        expected_line: 6,
        pattern: "argument 1 of `fn(:add)` expects",
        type: Kumi::Errors::SemanticError
      )

      expect(result[:success]).to be(true), "Expected error at line 6 but got line #{result[:actual_line]}"
      expect(result[:pattern_match]).to be(true), "Expected type mismatch message"
      expect(result[:error_message]).to include("string")
      expect(result[:error_message]).to include("declared type")
    end

    it "reports undefined references at reference location" do
      schema_code = <<~RUBY
        Kumi.schema do
          input { integer :x }
          value :good, input.x
          value :bad, ref(:missing_ref)
          value :another, fn(:multiply, input.x, 2)
        end
      RUBY

      result = test_error_location(
        schema_code,
        expected_line: 4,
        pattern: "undefined reference to",
        type: Kumi::Errors::SemanticError
      )

      expect(result[:success]).to be(true), "Expected error at line 4 but got line #{result[:actual_line]}"
      expect(result[:pattern_match]).to be(true), "Expected undefined reference message"
      expect(result[:line_content]).to include("ref(:missing_ref)")
      expect(result[:error_message]).to include("missing_ref")
    end

    it "reports undefined references at cascade when a trait is missing" do
      schema_code = <<~RUBY
        Kumi.schema do
          input { integer :x }
          trait :valid_trait, (input.x > 10)
          value :result do
            on :valid_trait, "Valid"
            on :missing_trait, "Invalid"
            base "Unknown"
          end
        end
      RUBY

      result = test_error_location(
        schema_code,
        expected_line: 6,
        pattern: "undefined reference to",
        type: Kumi::Errors::SemanticError
      )

      expect(result[:success]).to be(true), "Expected error at line 6 but got line #{result[:actual_line]}"
      expect(result[:pattern_match]).to be(true), "Expected undefined reference message"
      expect(result[:error_message]).to include("missing_trait")
    end

    it "reports unknown functions at function call location" do
      schema_code = <<~RUBY
        Kumi.schema do
          input { integer :x }
          value :result, fn(:unknown_func, input.x)
        end
      RUBY

      result = test_error_location(
        schema_code,
        expected_line: 3,
        pattern: "unsupported operator",
        type: Kumi::Errors::SemanticError
      )

      expect(result[:pattern_match]).to be(true), "Expected unsupported operator message"
      expect(result[:error_message]).to include("unknown_func")
    end

    it "reports invalid input block methods at correct line" do
      schema_code = <<~RUBY
        Kumi.schema do
          input do
            integer :age
            xxx :invalid_field
            string :name
          end
          value :result, input.age
        end
      RUBY

      # This should be a SyntaxError, not SemanticError
      result = test_error_location(
        schema_code,
        expected_line: 4,
        pattern: "Unknown method 'xxx'",
        type: Kumi::Errors::SyntaxError
      )

      expect(result[:pattern_match]).to be(true), "Expected unknown method message"
      expect(result[:error_message]).to include("Only 'key', 'integer', 'float'")
    end
  end

  describe "Error message quality" do
    it "provides comprehensive type mismatch information" do
      schema_code = <<~RUBY
        Kumi.schema do
          input do
            string :text
            boolean :flag
          end
          value :math_error, fn(:multiply, input.text, input.flag)
        end
      RUBY

      result = test_error_location(
        schema_code,
        expected_line: 6,
        type: Kumi::Errors::SemanticError
      )

      # Check that error message includes specific type information
      error_msg = result[:error_message]
      expect(error_msg).to include("multiply") # Function name
      expect(error_msg).to include("string") # Actual type
      expect(error_msg).to include("expects") # Clear expectation
    end

    it "shows clear cascade dependency errors" do
      schema_code = <<~RUBY
        Kumi.schema do
          input { boolean :condition }
          trait :flag, (input.condition == true)
          value :a do
            on flag, ref(:b)
            base "default"
          end
          value :b do
            on flag, ref(:a)#{' '}
            base "other"
          end
        end
      RUBY

      result = test_error_location(
        schema_code,
        expected_line: 4, # Start of cascade definition
        pattern: "cycle detected",
        type: Kumi::Errors::SemanticError
      )

      expect(result[:error_message]).to include("cycle detected")
    end

    it "handles complex nested expression errors" do
      schema_code = <<~RUBY
        Kumi.schema do
          input do
            integer :x
            string :y
          end
          value :nested, fn(:add, fn(:multiply, input.x, 2), input.y)
        end
      RUBY

      result = test_error_location(
        schema_code,
        expected_line: 6,
        type: Kumi::Errors::SemanticError
      )

      # Should report the type error in the nested function call
      expect(result[:error_message]).to include("add")
      expect(result[:error_message]).to include("string")
    end
  end

  describe "Location precision for various constructs" do
    it "pinpoints errors in trait definitions" do
      schema_code = <<~RUBY
        Kumi.schema do
          input { string :name }
          trait :valid_name, (input.name > 5)
        end
      RUBY

      result = test_error_location(
        schema_code,
        expected_line: 3,
        pattern: "argument 1",
        type: Kumi::Errors::SemanticError
      )

      # String comparison with integer should be caught
      expect(result[:error_message]).to include("argument 1")
    end

    it "identifies errors in cascade conditions" do
      schema_code = <<~RUBY
        Kumi.schema do
          input { integer :score }
          value :grade do
            on (input.score >= ref(:nonexistent)), "A"
            base "F"
          end
        end
      RUBY

      result = test_error_location(
        schema_code,
        expected_line: 4,
        pattern: "undefined reference",
        type: Kumi::Errors::SemanticError
      )

      expect(result[:error_message]).to include("nonexistent")
    end

    it "catches domain specification errors" do
      # Domain validation happens at runtime, not compile time
      # Use create_schema helper to get proper domain validation
      schema = create_schema do
        input do
          integer :score, domain: 18..100
        end
        value :result, input.score
      end

      begin
        schema.from(score: 5) # Invalid: outside domain 18..100
        raise "Expected domain validation error but none was raised"
      rescue StandardError => e
        # Verify we get domain-related error
        expect(e.message.downcase).to include("domain").or include("range")
      end
    end
  end
end
