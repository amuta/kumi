# frozen_string_literal: true

RSpec.describe "Type System Integration" do
  describe "basic type inference" do
    it "infers types for literal values" do
      schema_result = Kumi.schema do
        value :int_val, 42
        value :float_val, 3.14
        value :string_val, "hello"
        value :bool_val, true
      end

      types = schema_result.analyzer_result.decl_types

      expect(types[:int_val]).to eq(Kumi::Core::Types::INT)
      expect(types[:float_val]).to eq(Kumi::Core::Types::FLOAT)
      expect(types[:string_val]).to eq(Kumi::Core::Types::STRING)
      expect(types[:bool_val]).to eq(Kumi::Core::Types::BOOL)
    end

    it "uses annotated field types" do
      schema_result = Kumi.schema do
        input do
          key :age, type: Kumi::Core::Types::INT
        end

        value :age_check, fn(:>=, input.age, 18)
      end

      types = schema_result.analyzer_result.decl_types
      expect(types[:age_check]).to eq(Kumi::Core::Types::BOOL)
    end

    it "infers function return types" do
      schema_result = Kumi.schema do
        value :sum, fn(:add, 10, 20)
        value :comparison, fn(:>, 5, 3)
        value :text, fn(:upcase, "hello")
      end

      types = schema_result.analyzer_result.decl_types

      expect(types[:sum]).to eq(:integer)
      expect(types[:comparison]).to eq(Kumi::Core::Types::BOOL)
      expect(types[:text]).to eq(Kumi::Core::Types::STRING)
    end

    it "infers array types" do
      schema_result = Kumi.schema do
        value :numbers, [1, 2, 3]
        value :strings, %w[a b c]
      end

      types = schema_result.analyzer_result.decl_types

      expect(types[:numbers]).to eq({ array: :integer })
      expect(types[:strings]).to eq({ array: :string })
    end
  end

  describe "type propagation through dependencies" do
    it "propagates types through references" do
      schema_result = Kumi.schema do
        value :base_amount, 1000
        value :tax_rate, 0.08
        value :tax_amount, fn(:multiply, base_amount, tax_rate)
        value :total, fn(:add, base_amount, tax_amount)
      end

      types = schema_result.analyzer_result.decl_types

      expect(types[:base_amount]).to eq(Kumi::Core::Types::INT)
      expect(types[:tax_rate]).to eq(Kumi::Core::Types::FLOAT)
      expect(types[:tax_amount]).to eq(Kumi::Core::Types::NUMERIC)
      expect(types[:total]).to eq(:integer)
    end
  end

  # NOTE: Cascade expression type inference is implemented but has dependency resolution
  # issues in integration tests that need further investigation. The TypeInferencerPass
  # unit tests cover cascade type inference functionality.

  describe "backward compatibility" do
    it "works with existing schemas without type annotations" do
      expect do
        Kumi.schema do
          input do
            key :age
            key :base_price
          end

          trait :is_adult, input.age, :>=, 18
          value :discount, fn(:multiply, input.base_price, 0.1)
        end
      end.not_to raise_error
    end

    it "still validates function arity" do
      expect do
        Kumi.schema do
          value :invalid, fn(:add, 1) # add expects 2 arguments
        end
      end.to raise_error(Kumi::Core::Errors::TypeError, /signature mismatch/)
    end

    it "still validates unknown functions" do
      expect do
        Kumi.schema do
          value :invalid, fn(:unknown_function, 1, 2)
        end
      end.to raise_error(Kumi::Core::Errors::SemanticError, /unknown function/)
    end
  end

  describe "complex type scenarios" do
    it "handles nested function calls" do
      schema_result = Kumi.schema do
        value :nested, fn(:add, fn(:mul, 2, 3), fn(:sub, 10, 5))
      end

      types = schema_result.analyzer_result.decl_types
      expect(types[:nested]).to eq(:integer)
    end

    it "handles list operations" do
      schema_result = Kumi.schema do
        value :numbers, [1, 2, 3, 4, 5]
        value :sum_total, fn(:sum, numbers)
        value :first_num, fn(:first, numbers)
      end

      types = schema_result.analyzer_result.decl_types

      expect(types[:numbers]).to eq({ array: :integer })
      expect(types[:sum_total]).to eq(:integer)
      expect(types[:first_num]).to eq(:integer)
    end
  end

  describe "error scenarios" do
    it "validates at analysis time with type annotations" do
      # Enhanced type checker now validates field references against function parameter types
      expect do
        Kumi.schema do
          input do
            key :name, type: Kumi::Core::Types::STRING
          end

          value :invalid, fn(:add, input.name, 1)
        end
      end.to raise_error(Kumi::Core::Errors::SemanticError,
                         /argument 1 of `fn\(:add\)` expects float, got input field `name` of declared type string/)
    end
  end

  describe "type information access" do
    it "stores type information in analysis state" do
      schema_result = Kumi.schema do
        value :test_val, 42
      end

      expect(schema_result.analyzer_result.decl_types).to have_key(:test_val)
      expect(schema_result.analyzer_result.decl_types[:test_val]).to eq(Kumi::Core::Types::INT)
    end
  end

  describe "function registry type metadata" do
    it "includes type information in function signatures via RegistryV2" do
      registry = Kumi::Registry.registry_v2
      function = registry.resolve("core.add", arity: 2)

      expect(function.dtypes).to be_a(Hash)
      expect(function.dtypes).to have_key("result")
      expect(function.signatures).to be_an(Array)
      expect(function.signatures.first).to respond_to(:to_signature_string)
    end

    it "validates that core functions can be resolved with type metadata" do
      registry = Kumi::Registry.registry_v2
      sample_functions = ["core.add", "core.sub", "core.mul", "core.div", "core.gt", "core.lt"]
      
      sample_functions.each do |fn_name|
        function = registry.resolve(fn_name, arity: 2)
        
        expect(function.dtypes).to be_a(Hash), "Function #{fn_name} missing dtypes"
        expect(function.signatures).to be_an(Array), "Function #{fn_name} missing signatures"
        expect(function.name).to eq(fn_name), "Function name mismatch"
      end
    end
  end
end
