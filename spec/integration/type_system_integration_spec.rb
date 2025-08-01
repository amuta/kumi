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

      expect(types[:sum]).to eq(Kumi::Core::Types::NUMERIC)
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
      expect(types[:total]).to eq(Kumi::Core::Types::NUMERIC)
    end
  end

  # NOTE: Cascade expression type inference is implemented but has dependency resolution
  # issues in integration tests that need further investigation. The TypeInferencer
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
      end.to raise_error(Kumi::Core::Errors::SemanticError, /expects 2 args, got 1/)
    end

    it "still validates unknown functions" do
      expect do
        Kumi.schema do
          value :invalid, fn(:unknown_function, 1, 2)
        end
      end.to raise_error(Kumi::Core::Errors::SemanticError, /unsupported operator/)
    end
  end

  describe "complex type scenarios" do
    it "handles nested function calls" do
      schema_result = Kumi.schema do
        value :nested, fn(:add, fn(:multiply, 2, 3), fn(:subtract, 10, 5))
      end

      types = schema_result.analyzer_result.decl_types
      expect(types[:nested]).to eq(Kumi::Core::Types::NUMERIC)
    end

    it "handles list operations" do
      schema_result = Kumi.schema do
        value :numbers, [1, 2, 3, 4, 5]
        value :sum_total, fn(:sum, numbers)
        value :first_num, fn(:first, numbers)
      end

      types = schema_result.analyzer_result.decl_types

      expect(types[:numbers]).to eq({ array: :integer })
      expect(types[:sum_total]).to eq(:float)
      expect(types[:first_num]).to eq(:any)
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
    it "includes type information in function signatures" do
      signature = Kumi::Core::FunctionRegistry.signature(:add)

      expect(signature).to have_key(:param_types)
      expect(signature).to have_key(:return_type)
      expect(signature[:param_types]).to be_an(Array)
      expect(signature[:return_type]).to be_a(Symbol).or(be_a(Hash))
    end

    it "validates that all core functions have type metadata" do
      Kumi::Core::FunctionRegistry.all.each do |fn_name|
        signature = Kumi::Core::FunctionRegistry.signature(fn_name)

        expect(signature[:param_types]).to be_an(Array), "Function #{fn_name} missing param_types"
        expect(signature[:return_type]).to be_a(Symbol).or(be_a(Hash)), "Function #{fn_name} missing return_type"

        # Validate arity matches param_types (unless variable arity)
        next if signature[:arity] < 0

        expect(signature[:param_types].size).to eq(signature[:arity]).or(eq(1)),
                                                "Function #{fn_name} arity mismatch: " \
                                                "#{signature[:arity]} vs #{signature[:param_types].size}"
      end
    end
  end
end
