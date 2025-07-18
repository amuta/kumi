# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Input Block Feature" do
  include_context "schema generator"

  describe "input block DSL" do
    it "allows field declarations with type and domain metadata" do
      schema = create_schema do
        input do
          key :age, type: Kumi::Types::INT, domain: 0..120
          key :name, type: Kumi::Types::STRING
        end

        predicate :adult, input.age, :>=, 18
      end

      expect(schema.analysis.state[:input_meta][:age][:type]).to eq(Kumi::Types::INT)
      expect(schema.analysis.state[:input_meta][:age][:domain]).to eq(0..120)
      expect(schema.analysis.state[:input_meta][:name][:type]).to eq(Kumi::Types::STRING)
    end

    it "allows field reference via input.field_name syntax" do
      schema = create_schema do
        input do
          key :score, type: Kumi::Types::INT, domain: 0..100
        end

        predicate :passing, input.score, :>=, 60
      end

      result = schema.compiled.evaluate({ score: 75 })
      expect(result[:passing]).to be true

      result = schema.compiled.evaluate({ score: 45 })
      expect(result[:passing]).to be false
    end
  end

  describe "error handling" do
    it "raises error for conflicting type declarations" do
      expect do
        create_schema do
          input do
            key :age, type: Kumi::Types::INT
            key :age, type: Kumi::Types::STRING # Conflict!
          end
        end
      end.to raise_error(Kumi::Errors::SemanticError, /conflicting types/)
    end

    it "raises error for conflicting domain declarations" do
      expect do
        create_schema do
          input do
            key :score, domain: 0..100
            key :score, domain: 1..10 # Conflict!
          end
        end
      end.to raise_error(Kumi::Errors::SemanticError, /conflicting domains/)
    end

    it "raises error for unknown methods in input block" do
      expect do
        create_schema do
          input do
            predicate :invalid, true # Not allowed in input block
          end
        end
      end.to raise_error(Kumi::Errors::SyntaxError, /Unknown method 'predicate' in input block/)
    end
  end

  describe "type inference integration" do
    it "infers types from input block declarations" do
      schema = create_schema do
        input do
          key :age, type: Kumi::Types::INT
          key :name, type: Kumi::Types::STRING
        end

        value :info, fn(:concat, input.name, " is ", input.age, " years old")
      end

      # Check that field types are properly inferred
      input_meta = schema.analysis.state[:input_meta]
      expect(input_meta[:age][:type]).to eq(Kumi::Types::INT)
      expect(input_meta[:name][:type]).to eq(Kumi::Types::STRING)
    end

    it "raises error if input block is defined multiple times" do
      expect do
        create_schema do
          input do
            key :age, type: Kumi::Types::INT
          end

          input do
            key :name, type: Kumi::Types::STRING # Second input block should raise error
          end
        end
      end.to raise_error(Kumi::Errors::SyntaxError, /input block already defined/)
    end
  end

  describe "runner integration" do
    it "provides input method to access original data" do
      schema = create_schema do
        input do
          key :user_id, type: Kumi::Types::INT
        end

        predicate :valid_user, input.user_id, :>, 0
      end

      data = { user_id: 42, extra_data: "ignored" }
      runner = Kumi::Runner.new(data, schema.compiled, schema.analysis.definitions)

      expect(runner.input[:user_id]).to eq(42)
      expect(runner.input[:extra_data]).to eq("ignored")
      expect(runner.fetch(:valid_user)).to be true
    end
  end

  describe "compilation and execution" do
    it "compiles and executes schemas with input blocks correctly" do
      schema = create_schema do
        input do
          key :temperature, type: Kumi::Types::FLOAT
          key :threshold, type: Kumi::Types::FLOAT
        end

        predicate :hot, input.temperature, :>, input.threshold
        predicate :cold, input.temperature, :<, input.threshold
      end

      # Test hot condition
      result = schema.compiled.evaluate({ temperature: 25.0, threshold: 20.0 })
      expect(result[:hot]).to be true
      expect(result[:cold]).to be false

      # Test cold condition
      result = schema.compiled.evaluate({ temperature: 15.0, threshold: 20.0 })
      expect(result[:hot]).to be false
      expect(result[:cold]).to be true
    end
  end

  # Test compliance with simplified type system
  describe "symbol type declarations" do
    it "accepts :integer as type parameter" do
      schema = create_schema do
        input do
          key :age, type: :integer, domain: 0..120
        end

        predicate :adult, input.age, :>=, 18
      end

      expect(schema.analysis.state[:input_meta][:age][:type]).to eq(:integer)
    end

    it "accepts :string as type parameter" do
      schema = create_schema do
        input do
          key :name, type: :string
        end

        predicate :has_name, input.name, :!=, ""
      end

      expect(schema.analysis.state[:input_meta][:name][:type]).to eq(:string)
    end

    it "accepts :float as type parameter" do
      schema = create_schema do
        input do
          key :score, type: :float, domain: 0.0..100.0
        end

        predicate :passing, input.score, :>=, 60.0
      end

      expect(schema.analysis.state[:input_meta][:score][:type]).to eq(:float)
    end

    it "accepts :boolean as type parameter" do
      schema = create_schema do
        input do
          key :active, type: :boolean
          key :enabled, type: :boolean
        end

        predicate :is_active, input.active, :==, true
      end

      expect(schema.analysis.state[:input_meta][:active][:type]).to eq(:boolean)
      expect(schema.analysis.state[:input_meta][:enabled][:type]).to eq(:boolean)
    end

    it "accepts array type helper" do
      schema = create_schema do
        input do
          key :items, type: array(:any)
        end

        predicate :has_items, fn(:size, input.items), :>, 0
      end

      expected_type = { array: :any }
      expect(schema.analysis.state[:input_meta][:items][:type]).to eq(expected_type)
    end

    it "accepts hash type helper" do
      schema = create_schema do
        input do
          key :config, type: hash(:string, :any)
        end

        value :username, fn(:fetch, input.config, :username)
      end

      expected_type = { hash: %i[string any] }
      expect(schema.analysis.state[:input_meta][:config][:type]).to eq(expected_type)
    end

    it "still accepts legacy Kumi type constants" do
      schema = create_schema do
        input do
          key :age, type: Kumi::Types::INT
          key :name, type: Kumi::Types::STRING
        end

        predicate :adult, input.age, :>=, 18
      end

      expect(schema.analysis.state[:input_meta][:age][:type]).to eq(:integer)
      expect(schema.analysis.state[:input_meta][:name][:type]).to eq(:string)
    end

    it "raises error for unknown types" do
      expect do
        create_schema do
          input do
            key :unknown, type: :invalid_type
          end

          predicate :always_true, true, :==, true
        end
      end.to raise_error(Kumi::Errors::SyntaxError)
    end
  end

  describe "acceptance criteria" do
    it "Field declared once; referenced via input.age" do
      schema = create_schema do
        input do
          key :age, type: :integer, domain: 0..120
        end

        predicate :adult, input.age, :>=, 18
      end

      expect(schema.analysis.state[:input_meta][:age][:type]).to eq(:integer)
      expect(schema.analysis.decl_types[:adult]).to eq(:boolean)
    end

    it "raises when input references to undeclared field" do
      expect do
        create_schema do
          predicate :adult, input.age, :>=, 18 # No input block defined
        end
      end.to raise_error(Kumi::Errors::SemanticError, /undeclared input `age`/)
    end

    it "Two key :age declarations with different type" do
      expect do
        create_schema do
          input do
            key :age, type: Kumi::Types::INT
            key :age, type: Kumi::Types::STRING
          end
        end
      end.to raise_error(Kumi::Errors::SemanticError, /conflicting types/)
    end

    it "key() method no longer exists" do
      expect do
        create_schema do
          predicate :adult, key(:age), :>=, 18
        end
      end.to raise_error(NoMethodError, /undefined method `key'/)
    end
  end
end
