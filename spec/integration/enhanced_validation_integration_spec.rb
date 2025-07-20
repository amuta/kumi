# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Enhanced Validation Integration" do
  include_context "schema generator"

  describe "type-specific DSL methods with runtime validation" do
    context "with new DSL syntax" do
      let(:schema) do
        create_schema do
          input do
            integer      :score
            float        :base_discount, domain: 0.0..1.0
            string       :customer_tier, domain: %w[bronze silver gold platinum]
            boolean      :is_active
            key          :tags, type: array(:any)
            array        :scores, elem: { type: :float }
            key          :settings, type: hash(:any, :any)
            hash         :config, key: { type: :string }, val: { type: :integer }
          end

          trait :premium_customer, input.customer_tier, :==, "platinum"
          value :total_score, fn(:add, input.score, fn(:multiply, input.base_discount, 100))
        end
      end

      it "validates type-specific fields correctly with valid data" do
        valid_data = {
          score: 85,
          base_discount: 0.15,
          customer_tier: "gold",
          is_active: true,
          tags: %w[premium vip],
          scores: [85.5, 92.3, 78.1],
          settings: { theme: "dark", notifications: true },
          config: { "max_items" => 10, "timeout" => 30 }
        }

        runner = schema.from(valid_data)
        expect(runner.fetch(:premium_customer)).to be false
        expect(runner.fetch(:total_score)).to eq(100) # 85 + (0.15 * 100)
      end

      it "validates integer fields and rejects non-integers" do
        invalid_data = {
          score: "85", # String instead of integer
          base_discount: 0.15,
          customer_tier: "gold",
          is_active: true,
          tags: [],
          scores: [],
          settings: {},
          config: {}
        }

        error = nil
        expect do
          schema.from(invalid_data)
        end.to raise_error(Kumi::Errors::InputValidationError) { |e| error = e }

        expect(error.type_violations?).to be true
        type_violation = error.type_violations.first
        expect(type_violation[:field]).to eq(:score)
        expect(type_violation[:expected_type]).to eq(:integer)
        expect(type_violation[:actual_type]).to eq(:string)
      end

      it "validates float fields with domain constraints" do
        invalid_data = {
          score: 85,
          base_discount: 1.5, # Outside domain 0.0..1.0
          customer_tier: "gold",
          is_active: true,
          tags: [],
          scores: [],
          settings: {},
          config: {}
        }

        error = nil
        expect do
          schema.from(invalid_data)
        end.to raise_error(Kumi::Errors::InputValidationError) { |e| error = e }

        expect(error.domain_violations?).to be true
        domain_violation = error.domain_violations.first
        expect(domain_violation[:field]).to eq(:base_discount)
        expect(domain_violation[:domain]).to eq(0.0..1.0)
      end

      it "validates string fields with enumeration domains" do
        invalid_data = {
          score: 85,
          base_discount: 0.15,
          customer_tier: "diamond", # Not in allowed values
          is_active: true,
          tags: [],
          scores: [],
          settings: {},
          config: {}
        }

        error = nil
        expect do
          schema.from(invalid_data)
        end.to raise_error(Kumi::Errors::InputValidationError) { |e| error = e }

        expect(error.domain_violations?).to be true
        domain_violation = error.domain_violations.first
        expect(domain_violation[:field]).to eq(:customer_tier)
        expect(domain_violation[:domain]).to eq(%w[bronze silver gold platinum])
      end

      it "validates typed array elements" do
        invalid_data = {
          score: 85,
          base_discount: 0.15,
          customer_tier: "gold",
          is_active: true,
          tags: [],
          scores: [85.5, "invalid", 78.1], # Mixed types in typed array
          settings: {},
          config: {}
        }

        error = nil
        expect do
          schema.from(invalid_data)
        end.to raise_error(Kumi::Errors::InputValidationError) { |e| error = e }

        expect(error.type_violations?).to be true
        type_violation = error.type_violations.first
        expect(type_violation[:field]).to eq(:scores)
        expect(type_violation[:expected_type]).to eq({ array: :float })
      end

      it "validates typed hash keys and values" do
        invalid_data = {
          score: 85,
          base_discount: 0.15,
          customer_tier: "gold",
          is_active: true,
          tags: [],
          scores: [],
          settings: {},
          config: { "valid_key" => 10, :invalid_key => 20 } # Symbol key instead of string
        }

        error = nil
        expect do
          schema.from(invalid_data)
        end.to raise_error(Kumi::Errors::InputValidationError) { |e| error = e }

        expect(error.type_violations?).to be true
        type_violation = error.type_violations.first
        expect(type_violation[:field]).to eq(:config)
        expect(type_violation[:expected_type]).to eq({ hash: %i[string integer] })
      end

      it "allows flexible typing for untyped arrays and hashes" do
        flexible_data = {
          score: 85,
          base_discount: 0.15,
          customer_tier: "gold",
          is_active: true,
          tags: ["string", :symbol, 123, true], # Mixed types allowed
          scores: [],
          settings: { "string_key" => "value", :symbol_key => 123, 1 => true }, # Mixed types allowed
          config: {}
        }

        expect do
          runner = schema.from(flexible_data)
          expect(runner.fetch(:premium_customer)).to be false
        end.not_to raise_error
      end
    end

    context "with complex nested structures" do
      let(:nested_schema) do
        create_schema do
          input do
            array :users, elem: { type: hash(:string, :any) }
            hash :metadata, key: { type: :string }, val: { type: array(:string) }
          end

          trait :has_users, fn(:size, input.users), :>, 0
        end
      end

      it "validates nested array of hashes" do
        valid_data = {
          users: [
            { "name" => "John", "age" => 30 },
            { "name" => "Jane", "age" => 25 }
          ],
          metadata: {
            "tags" => %w[user admin],
            "categories" => %w[premium standard]
          }
        }

        expect do
          runner = nested_schema.from(valid_data)
          expect(runner.fetch(:has_users)).to be true
        end.not_to raise_error
      end

      it "rejects invalid nested structures" do
        invalid_data = {
          users: [
            { "name" => "John", "age" => 30 },
            { symbol_key: "Jane" } # Symbol key instead of string
          ],
          metadata: {}
        }

        expect do
          nested_schema.from(invalid_data)
        end.to raise_error(Kumi::Errors::InputValidationError)
      end
    end

    context "with mixed validation errors" do
      let(:mixed_schema) do
        create_schema do
          input do
            integer :age, domain: 18..65
            string :status, domain: %w[active inactive]
            float :score, domain: 0.0..100.0
          end

          trait :eligible, input.age, :>=, 21
        end
      end

      it "reports both type and domain violations together" do
        invalid_data = {
          age: "30", # Type violation: string instead of integer
          status: "unknown", # Domain violation: not in allowed values
          score: 150.0 # Domain violation: outside range
        }

        error = nil
        expect do
          mixed_schema.from(invalid_data)
        end.to raise_error(Kumi::Errors::InputValidationError) { |e| error = e }

        expect(error.multiple_violations?).to be true
        expect(error.type_violations.size).to eq(1)
        expect(error.domain_violations.size).to eq(2)

        type_violation = error.type_violations.first
        expect(type_violation[:field]).to eq(:age)

        domain_fields = error.domain_violations.map { |v| v[:field] }
        expect(domain_fields).to contain_exactly(:status, :score)
      end

      it "prioritizes type checking over domain checking for the same field" do
        invalid_data = {
          age: "16", # Wrong type AND would be wrong domain
          status: "active", # Correct
          score: 85.0 # Correct
        }

        error = nil
        expect do
          mixed_schema.from(invalid_data)
        end.to raise_error(Kumi::Errors::InputValidationError) { |e| error = e }

        expect(error.single_violation?).to be true
        expect(error.type_violations?).to be true
        expect(error.domain_violations?).to be false

        violation = error.violations.first
        expect(violation[:field]).to eq(:age)
        expect(violation[:type]).to eq(:type_violation)
      end
    end
  end

  describe "custom domain validation" do
    context "with proc domains" do
      let(:proc_schema) do
        create_schema do
          input do
            string :email, domain: ->(v) { v.match?(/\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i) }
            string :password, domain: ->(v) { v.length >= 8 && v.match?(/[A-Z]/) && v.match?(/[0-9]/) }
          end

          trait :valid_credentials, input.email, :!=, ""
        end
      end

      it "validates email format using custom proc" do
        valid_data = {
          email: "user@example.com",
          password: "StrongPass123"
        }

        expect do
          runner = proc_schema.from(valid_data)
          expect(runner.fetch(:valid_credentials)).to be true
        end.not_to raise_error
      end

      it "rejects invalid email format" do
        invalid_data = {
          email: "invalid-email", # Invalid format
          password: "StrongPass123"
        }

        error = nil
        expect do
          proc_schema.from(invalid_data)
        end.to raise_error(Kumi::Errors::InputValidationError) { |e| error = e }

        expect(error.domain_violations?).to be true
        domain_violation = error.domain_violations.first
        expect(domain_violation[:field]).to eq(:email)
        expect(domain_violation[:message]).to include("custom domain constraint")
      end

      it "rejects weak password" do
        invalid_data = {
          email: "user@example.com",
          password: "weak" # Doesn't meet complexity requirements
        }

        error = nil
        expect do
          proc_schema.from(invalid_data)
        end.to raise_error(Kumi::Errors::InputValidationError) { |e| error = e }

        expect(error.domain_violations?).to be true
        domain_violation = error.domain_violations.first
        expect(domain_violation[:field]).to eq(:password)
        expect(domain_violation[:message]).to include("custom domain constraint")
      end

      it "provides meaningful error messages for multiple proc violations" do
        invalid_data = {
          email: "bad-email",
          password: "weak"
        }

        error = nil
        expect do
          proc_schema.from(invalid_data)
        end.to raise_error(Kumi::Errors::InputValidationError) { |e| error = e }

        expect(error.multiple_violations?).to be true
        expect(error.domain_violations.size).to eq(2)

        fields = error.domain_violations.map { |v| v[:field] }
        expect(fields).to contain_exactly(:email, :password)
      end
    end

    context "with exclusive ranges" do
      let(:exclusive_schema) do
        create_schema do
          input do
            float :probability, domain: 0.0...1.0
            integer :percentage, domain: 0..100
          end

          trait :likely, input.probability, :>, 0.5
        end
      end

      it "accepts values within exclusive range" do
        valid_data = {
          probability: 0.999,
          percentage: 85
        }

        expect do
          runner = exclusive_schema.from(valid_data)
          expect(runner.fetch(:likely)).to be true
        end.not_to raise_error
      end

      it "rejects the excluded end value" do
        invalid_data = {
          probability: 1.0, # Excluded from 0.0...1.0
          percentage: 85
        }

        error = nil
        expect do
          exclusive_schema.from(invalid_data)
        end.to raise_error(Kumi::Errors::InputValidationError) { |e| error = e }

        expect(error.domain_violations?).to be true
        domain_violation = error.domain_violations.first
        expect(domain_violation[:field]).to eq(:probability)
        expect(domain_violation[:message]).to include("(exclusive)")
      end

      it "accepts the included end value for inclusive ranges" do
        valid_data = {
          probability: 0.5,
          percentage: 100 # Included in 0..100
        }

        expect do
          exclusive_schema.from(valid_data)
        end.not_to raise_error
      end
    end
  end

  describe "backwards compatibility with enhanced validation" do
    context "with legacy key syntax" do
      let(:legacy_schema) do
        create_schema do
          input do
            key :age, type: :integer, domain: 18..65
            key :name, type: :string
            key :scores, type: array(:float)
          end

          trait :adult, input.age, :>=, 18
        end
      end

      it "validates legacy syntax with same rigor as new syntax" do
        invalid_data = {
          age: "25", # Type violation
          name: "John",
          scores: [85.5, "invalid"] # Type violation in array
        }

        error = nil
        expect do
          legacy_schema.from(invalid_data)
        end.to raise_error(Kumi::Errors::InputValidationError) { |e| error = e }

        expect(error.type_violations.size).to eq(2)
        fields = error.type_violations.map { |v| v[:field] }
        expect(fields).to contain_exactly(:age, :scores)
      end
    end

    context "with mixed legacy and new syntax" do
      let(:mixed_schema) do
        create_schema do
          input do
            key :legacy_field, type: :string, domain: %w[old style]
            integer :new_field, domain: 1..100
          end

          trait :both_valid, input.legacy_field, :!=, ""
        end
      end

      it "validates both syntaxes consistently" do
        invalid_data = {
          legacy_field: "invalid", # Domain violation
          new_field: 150 # Domain violation
        }

        error = nil
        expect do
          mixed_schema.from(invalid_data)
        end.to raise_error(Kumi::Errors::InputValidationError) { |e| error = e }

        expect(error.domain_violations.size).to eq(2)
        fields = error.domain_violations.map { |v| v[:field] }
        expect(fields).to contain_exactly(:legacy_field, :new_field)
      end
    end
  end

  describe "error message quality and clarity" do
    let(:error_schema) do
      create_schema do
        input do
          integer :count
          string :status, domain: %w[active inactive]
          array :items, elem: { type: :string }
          hash :config, key: { type: :string }, val: { type: :integer }
        end

        trait :valid, input.count, :>, 0
      end
    end

    it "provides clear, detailed error messages for type violations" do
      invalid_data = {
        count: "not_integer",
        status: "active",
        items: ["valid", 123, "also_valid"],
        config: { "valid" => 42 }
      }

      error = nil
      expect do
        error_schema.from(invalid_data)
      end.to raise_error(Kumi::Errors::InputValidationError) { |e| error = e }

      expect(error.type_violations.size).to eq(2)

      count_violation = error.type_violations.find { |v| v[:field] == :count }
      expect(count_violation[:message]).to include("Field :count")
      expect(count_violation[:message]).to include("expected integer")
      expect(count_violation[:message]).to include('"not_integer"')
      expect(count_violation[:message]).to include("of type string")

      items_violation = error.type_violations.find { |v| v[:field] == :items }
      expect(items_violation[:message]).to include("Field :items")
      expect(items_violation[:message]).to include("expected array(string)")
      expect(items_violation[:message]).to include("of type array(mixed)")
    end

    it "provides clear error messages for domain violations" do
      invalid_data = {
        count: 5,
        status: "unknown",
        items: %w[valid strings],
        config: { "valid" => 42 }
      }

      error = nil
      expect do
        error_schema.from(invalid_data)
      end.to raise_error(Kumi::Errors::InputValidationError) { |e| error = e }

      expect(error.domain_violations.size).to eq(1)

      status_violation = error.domain_violations.first
      expect(status_violation[:message]).to include("Field :status")
      expect(status_violation[:message]).to include('value "unknown"')
      expect(status_violation[:message]).to include("not in allowed values")
      expect(status_violation[:message]).to include('["active", "inactive"]')
    end

    it "formats multiple violations with clear structure" do
      invalid_data = {
        count: "invalid",
        status: "unknown",
        items: ["valid"],
        config: { "valid" => 42 }
      }

      error = nil
      expect do
        error_schema.from(invalid_data)
      end.to raise_error(Kumi::Errors::InputValidationError) { |e| error = e }

      message = error.message
      expect(message).to include("Type violations:")
      expect(message).to include("Domain violations:")
      expect(message).to include("- Field :count")
      expect(message).to include("- Field :status")
    end
  end
end
