# frozen_string_literal: true

RSpec.describe "DSL Breakage Integration Tests" do
  describe "Syntax Errors" do
    describe "Invalid DSL structure" do
      it "allows missing input block (valid design choice)" do
        expect do
          schema do
            value :result, 42
          end
        end.not_to raise_error
      end

      it "catches invalid trait syntax" do
        error = expect_syntax_error do
          schema do
            input { integer :age }
            trait :adult # Missing expression
          end
        end
        expect(error).to include_error_pattern("trait")
      end

      it "catches invalid value syntax" do
        error = expect_syntax_error do
          schema do
            input { integer :age }
            value
          end
        end
        expect(error).to include_error_pattern("value")
      end

      it "catches malformed cascade blocks" do
        error = expect_syntax_error do
          schema do
            input { any :status }
            value :result do
              on
            end
          end
        end
        expect(error).to include_error_pattern("cascade")
      end

      it "catches unclosed blocks and parentheses" do
        expect do
          eval <<~RUBY
            Kumi.schema do
              input { any :field
              value :result, 42
            end
          RUBY
        end.to raise_error(SyntaxError)
      end
    end

    describe "Input block violations" do
      it "catches duplicate input blocks" do
        error = expect_syntax_error do
          schema do
            input { any :age }
            input { any :name }
            value :result, 42
          end
        end
        expect(error).to include_error_pattern("input")
      end

      it "catches invalid field declarations" do
        expect do
          schema do
            input do
              string # Missing field name
            end
            value :result, 42
          end
        end.to raise_error
      end

      it "catches invalid type specifications" do
        expect do
          schema do
            input do
              invalid_type :field
            end
            value :result, 42
          end
        end.to raise_error
      end
    end

    describe "Expression malformation" do
      it "catches malformed function calls" do
        expect do
          schema do
            input { any :x }
            value :result, fn
          end
        end.to raise_error
      end

      it "catches invalid field references" do
        expect do
          eval <<~RUBY
            Kumi.schema do
              input { any :x }
              value :result, input.
            end
          RUBY
        end.to raise_error(SyntaxError)
      end

      it "catches broken operator chaining" do
        expect do
          eval <<~RUBY
            Kumi.schema do
              input { any :x }
              trait :test, (input.x >=)
            end
          RUBY
        end.to raise_error(SyntaxError)
      end
    end
  end

  describe "Semantic Errors" do
    describe "Name conflicts and resolution" do
      it "catches duplicate trait names" do
        error = expect_semantic_error do
          schema do
            input { any :age }
            trait :adult, input.age, :>=, 18
            trait :adult, input.age, :>=, 21
          end
        end
        expect(error).to include_error_pattern("duplicated definition")
      end

      it "catches duplicate value names" do
        error = expect_semantic_error do
          schema do
            input { any :score }
            value :rating, "high"
            value :rating, "medium"
          end
        end
        expect(error).to include_error_pattern("duplicated definition")
      end

      it "catches trait/value name conflicts" do
        error = expect_semantic_error do
          schema do
            input { any :x }
            trait :item, input.x, :>, 0
            value :item, "value"
          end
        end
        expect(error).to include_error_pattern("duplicated definition")
      end

      it "catches references to undefined names" do
        error = expect_semantic_error do
          schema do
            input { any :x }
            value :result, ref(:undefined_item)
          end
        end
        expect(error).to include_error_pattern("undefined")
      end
    end

    describe "Circular dependencies" do
      it "catches simple circular dependencies" do
        error = expect_semantic_error do
          schema do
            input { any :x }
            value :a, ref(:b)
            value :b, ref(:a)
          end
        end
        expect(error).to include_error_pattern("cycle detected")
      end

      it "catches complex circular dependencies" do
        error = expect_semantic_error do
          schema do
            input { any :x }
            value :a, ref(:b)
            value :b, ref(:c)
            value :c, ref(:d)
            value :d, ref(:a)
          end
        end
        expect(error).to include_error_pattern("cycle detected")
      end

      it "catches self-referencing values" do
        error = expect_semantic_error do
          schema do
            input { any :x }
            value :recursive, ref(:recursive)
          end
        end
        expect(error).to include_error_pattern("cycle detected")
      end

      it "catches circular cascade dependencies" do
        error = expect_semantic_error do
          schema do
            input { any :condition }
            trait :flag, (input.condition == true)
            value :a do
              on flag, ref(:b)
              base "default"
            end
            value :b do
              on flag, ref(:a)
              base "other"
            end
          end
        end
        expect(error).to include_error_pattern("cycle detected")
      end
    end

    describe "Type system violations" do
      it "catches type mismatches in function calls" do
        error = expect_type_error do
          schema do
            input do
              string :name
              integer :age
            end
            value :result, fn(:add, input.name, input.age)
          end
        end
        expect(error).to include_error_pattern("expects")
      end

      it "catches incompatible operator usage" do
        error = expect_type_error do
          schema do
            input { string :text }
            trait :test, input.text, :>, 5
          end
        end
        expect(error).to include_error_pattern("expects")
      end

      it "catches array/hash type violations" do
        error = expect_type_error do
          schema do
            input do
              array :numbers, elem: { type: :integer }
            end
            value :result, fn(:add, input.numbers, "string")
          end
        end
        expect(error).to include_error_pattern("expects")
      end
    end

    describe "Domain constraint violations" do
      it "catches invalid domain specifications" do
        pending "Domain constraints type checking not yet implemented"
        error = expect_semantic_error do
          schema do
            input do
              integer :age, domain: "invalid"
            end
            value :result, input.age
          end
        end
        expect(error).to include_error_pattern("domain")
      end

      it "catches conflicting domain constraints" do
        # This tests field metadata conflicts during input collection
        expect do
          schema do
            input do
              integer :score, domain: 0..100
              integer :score, domain: 50..150
            end
            value :result, input.score
          end
        end.to raise_error
      end
    end

    describe "Function registry errors" do
      it "catches unknown function calls" do
        error = expect_semantic_error do
          schema do
            input { any :x }
            value :result, fn(:unknown_function, input.x)
          end
        end
        expect(error).to include_error_pattern("unsupported operator")
      end

      it "catches incorrect function arity" do
        error = expect_semantic_error do
          schema do
            input do
              integer :x
              integer :y
            end
            value :result, fn(:add, input.x)
          end
        end
        expect(error).to include_error_pattern("expects")
      end
    end
  end

  describe "Runtime Errors" do
    describe "Input validation failures" do
      it "catches type violations at runtime" do
        schema = build_schema do
          input { integer :number }
          value :result, fn(:multiply, input.number, 2)
        end

        error = expect_runtime_error(schema, { number: "not_a_number" })
        expect(error).to include_error_pattern("expected integer")
      end

      it "catches domain violations at runtime" do
        schema = build_schema do
          input { integer :age, domain: 0..120 }
          value :result, input.age
        end

        error = expect_runtime_error(schema, { age: 150 })
        expect(error).to include_error_pattern("domain")
      end

      it "catches complex type violations" do
        schema = build_schema do
          input do
            array :scores, elem: { type: :integer }
          end
          value :average, fn(:divide, fn(:sum, input.scores), fn(:length, input.scores))
        end

        error = expect_runtime_error(schema, { scores: %w[not integers] })
        expect(error).to include_error_pattern("type")
      end

      it "catches hash type violations" do
        schema = build_schema do
          input do
            hash :metadata, key: { type: :string }, val: { type: :integer }
          end
          value :result, input.metadata
        end

        error = expect_runtime_error(schema, { metadata: { "key" => "not_integer" } })
        expect(error).to include_error_pattern("type")
      end
    end

    describe "Function execution errors" do
      before do
        Kumi::FunctionRegistry.register(:error_prone) do |should_fail|
          raise "Function execution failed!" if should_fail

          "success"
        end
      end

      after do
        Kumi::FunctionRegistry.reset!
      end
    end

    describe "State corruption scenarios" do
      it "handles corrupted dependency graphs" do
        schema = build_schema do
          input { integer :x }
          value :result, input.x
        end

        # Simulate corrupted state by trying to fetch non-existent binding
        expect do
          schema.from(x: 5).fetch(:non_existent)
        end.to raise_error(Kumi::Errors::RuntimeError)
      end
    end
  end

  describe "Future DSL Features" do
    describe "Basic arithmetic operators (planned)" do
      it "supports input.x + 2 syntax" do
        schema_class = Class.new do
          extend Kumi::Schema

          schema do
            input { integer :x }
            value :result, input.x + 2
          end
        end

        runner = schema_class.from(x: 5)
        expect(runner.fetch(:result)).to eq(7)
      end

      it "supports input.x * 2 syntax" do
        schema_class = Class.new do
          extend Kumi::Schema

          schema do
            input { integer :x }
            value :result, input.x * 2
          end
        end

        runner = schema_class.from(x: 5)
        expect(runner.fetch(:result)).to eq(10)
      end

      it "supports input.name + ' suffix' syntax" do
        schema_class = Class.new do
          extend Kumi::Schema

          schema do
            input { string :name }
            value :result, fn(:concat, input.name, " suffix")
          end
        end

        runner = schema_class.from(name: "test")
        expect(runner.fetch(:result)).to eq("test suffix")
      end
    end
  end

  describe "Edge Cases and Boundary Conditions" do
    describe "Memory and performance limits" do
      it "handles large schemas without excessive memory usage" do
        expect do
          build_schema do
            input { integer :base }

            # Generate many interdependent values
            100.times do |i|
              value :"val_#{i}", fn(:add, input.base, i)
            end
          end
        end.not_to raise_error
      end

      it "handles deeply nested expressions" do
        expect do
          build_schema do
            input { integer :x }
            # Create nested expression manually
            nested_expr = (1..10).reduce(:x) { |acc, i| [:fn, :add, acc, i] }
            value :result, nested_expr
          end
        end.not_to raise_error
      end
    end

    describe "Unicode and special character handling" do
      it "handles Unicode field names" do
        expect do
          schema do
            input { integer :年齢 }
            value :結果, fn(:multiply, input.年齢, 2)
          end
        end.not_to raise_error
      end

      it "handles special characters in string literals" do
        expect do
          schema do
            input { string :text }
            value :result, "Special chars: \n\t\r\""
          end
        end.not_to raise_error
      end
    end

    describe "Concurrent execution issues" do
      it "handles thread safety in schema compilation" do
        threads = 5.times.map do
          Thread.new do
            build_schema do
              input { integer :x }
              value :result, fn(:multiply, input.x, 2)
            end
          end
        end

        expect { threads.each(&:join) }.not_to raise_error
      end

      it "handles concurrent schema execution" do
        schema = build_schema do
          input { integer :value }
          value :doubled, fn(:multiply, input.value, 2)
        end

        threads = 10.times.map do |i|
          Thread.new do
            schema.from(value: i).fetch(:doubled)
          end
        end

        results = threads.map(&:value)
        expect(results).to eq((0..9).map { |i| i * 2 })
      end
    end
  end

  describe "Error Quality and Clarity" do
    it "provides helpful error messages with location information" do
      schema do
        input { integer :age }
        trait :invalid, (input.nonexistent_field > 0)
      end
    rescue Kumi::Errors::SemanticError => e
      expect(e.message).to include("nonexistent_field")
      expect(e.location).not_to be_nil
      expect(e.location.line).to be > 0
    end

    it "suggests corrections for common mistakes" do
      schema do
        input { integer :age }
        value :result, ref(:unknown_reference)
      end
    rescue Kumi::Errors::SemanticError => e
      expect(e.message).to include("unknown_reference")
    end

    it "provides type-specific error messages" do
      schema do
        input { string :name }
        value :result, fn(:add, input.name, 5)
      end
    rescue Kumi::Errors::TypeError => e
      expect(e.message).to include("add")
      expect(e.message).to include("string")
    end
  end
end
