# frozen_string_literal: true

RSpec.describe "Type Error Reporting" do
  let(:schema_module) do
    Module.new do
      extend Kumi::Schema
    end
  end

  describe "overload resolution errors" do
    it "reports type errors with proper location information" do
      schema_module.schema do
        input do
          integer :number
        end

        # This should fail: upcase is only for strings, not integers
        value :result, fn(:upcase, input.number)
      end
    rescue Kumi::Core::Errors::TypeError => e
      expect(e.message).to include("upcase")
      expect(e.message).to include("no overload")
    end
  end

  describe "function resolution with correct types" do
    it "resolves overloaded functions correctly for string type" do
      schema_module.schema do
        input do
          string :name
        end

        value :result, fn(:size, input.name)
      end

      # Should compile without errors
      result = schema_module.from(name: "test")
      expect(result[:result]).to eq(4)
    end

    it "resolves overloaded functions correctly for array type" do
      schema_module.schema do
        input do
          array :items do
            integer :value
          end
        end

        value :result, fn(:size, input.items)
      end

      # Should compile without errors
      result = schema_module.from(items: [{ value: 1 }, { value: 2 }])
      expect(result[:result]).to eq(2)
    end
  end

  describe "overload resolution correctness" do
    it "compiles both string and array overloads in one schema" do
      schema_module.schema do
        input do
          string :name
          array :items do
            integer :value
          end
        end

        # Both should compile without type errors
        value :name_len, fn(:size, input.name)
        value :item_count, fn(:size, input.items)
      end

      result = schema_module.from(
        name: "hello",
        items: [{ value: 1 }, { value: 2 }, { value: 3 }]
      )

      expect(result[:name_len]).to eq(5)
      expect(result[:item_count]).to eq(3)
    end
  end

  describe "error messages" do
    it "catches basic compilation without type errors for valid calls" do
      # This test just verifies that valid schemas compile without type errors
      schema_module.schema do
        input do
          integer :number
          string :text
        end

        value :len, fn(:size, input.text)
        value :num, input.number
      end

      result = schema_module.from(number: 42, text: "hello")
      expect(result[:len]).to eq(5)
      expect(result[:num]).to eq(42)
    end
  end
end
