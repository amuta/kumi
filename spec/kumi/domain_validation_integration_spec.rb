# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Domain Validation Integration" do
  include_context "schema generator"

  describe "Schema.from with domain validation" do
    let(:schema) do
      create_schema do
        input do
          key :age, type: :integer, domain: 18..65
          key :score, type: :float, domain: 0.0..100.0
          key :status, type: :string, domain: %w[active inactive pending]
        end

        trait :adult, input.age, :>=, 18
        value :grade, fn(:conditional, fn(:>=, input.score, 90), "A", "B")
      end
    end

    context "with valid input" do
      it "creates runner successfully" do
        runner = schema.from({ age: 25, score: 85.0, status: "active" })

        expect(runner).to be_a(Kumi::Core::SchemaInstance)
        expect(runner[:adult]).to be true
        expect(runner[:grade]).to eq("B")
      end

      it "accepts boundary values" do
        expect do
          schema.from({ age: 18, score: 0.0, status: "active" })
        end.not_to raise_error

        expect do
          schema.from({ age: 65, score: 100.0, status: "pending" })
        end.not_to raise_error
      end
    end

    context "with domain violations" do
      it "raises DomainViolationError for single violation" do
        error = nil
        expect do
          schema.from({ age: 17, score: 85.0, status: "active" })
        end.to raise_error(Kumi::Core::Errors::InputValidationError) { |e| error = e }

        expect(error.single_violation?).to be true
        expect(error.violations.first[:field]).to eq(:age)
        expect(error.message).to include("Field :age value 17 is outside domain 18..65")
      end

      it "raises DomainViolationError for multiple violations" do
        error = nil
        expect do
          schema.from({ age: 16, score: 110.0, status: "unknown" })
        end.to raise_error(Kumi::Core::Errors::InputValidationError) { |e| error = e }

        expect(error.multiple_violations?).to be true
        expect(error.violations.size).to eq(3)

        fields = error.violations.map { |v| v[:field] }
        expect(fields).to contain_exactly(:age, :score, :status)

        expect(error.message).to include("Domain violations:")
        expect(error.message).to include("Field :age value 16")
        expect(error.message).to include("Field :score value 110.0")
        expect(error.message).to include("Field :status value \"unknown\"")
      end

      it "provides detailed violation information" do
        error = nil
        expect do
          schema.from({ age: 70, score: 85.0, status: "active" })
        end.to raise_error(Kumi::Core::Errors::InputValidationError) { |e| error = e }

        violation = error.violations.first
        expect(violation[:field]).to eq(:age)
        expect(violation[:value]).to eq(70)
        expect(violation[:domain]).to eq(18..65)
        expect(violation[:message]).to be_a(String)
      end
    end

    context "with missing domain constraints" do
      let(:schema_no_domains) do
        create_schema do
          input do
            key :name, type: :string
            key :count, type: :integer
          end

          trait :has_name, input.name, :!=, ""
        end
      end

      it "allows any values when no domains specified" do
        expect do
          runner = schema_no_domains.from({ name: "any name", count: 999_999 })
          expect(runner[:has_name]).to be true
        end.not_to raise_error
      end
    end

    context "with mixed domain and no-domain fields" do
      let(:mixed_schema) do
        create_schema do
          input do
            key :name, type: :string # no domain
            key :age, type: :integer, domain: 18..65 # has domain
            key :comment, type: :string # no domain
          end

          value :display_name, input.name
        end
      end

      it "validates only fields with domains" do
        # This should work - age is valid, other fields have no constraints
        expect do
          mixed_schema.from({ name: "Any Name", age: 25, comment: "Any comment" })
        end.not_to raise_error

        # This should fail - age violates domain
        expect do
          mixed_schema.from({ name: "Any Name", age: 17, comment: "Any comment" })
        end.to raise_error(Kumi::Core::Errors::InputValidationError)
      end
    end
  end

  describe "Custom domain types" do
    context "with Proc domains" do
      let(:email_schema) do
        create_schema do
          input do
            key :email, type: :string, domain: ->(v) { v.match?(/\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i) }
          end

          trait :valid_email, input.email, :!=, ""
        end
      end

      it "validates using custom proc" do
        expect do
          email_schema.from({ email: "user@example.com" })
        end.not_to raise_error

        error = nil
        expect do
          email_schema.from({ email: "invalid-email" })
        end.to raise_error(Kumi::Core::Errors::InputValidationError) { |e| error = e }

        expect(error.message).to include("does not satisfy custom domain constraint")
      end
    end

    context "with exclusive ranges" do
      let(:probability_schema) do
        create_schema do
          input do
            key :probability, type: :float, domain: 0.0...1.0
          end

          trait :likely, input.probability, :>, 0.5
        end
      end

      it "handles exclusive end correctly" do
        expect do
          probability_schema.from({ probability: 0.0 })
        end.not_to raise_error

        expect do
          probability_schema.from({ probability: 0.999 })
        end.not_to raise_error

        error = nil
        expect do
          probability_schema.from({ probability: 1.0 })
        end.to raise_error(Kumi::Core::Errors::InputValidationError) { |e| error = e }

        expect(error.message).to include("(exclusive)")
      end
    end
  end

  describe "Error message formatting" do
    let(:error_schema) do
      create_schema do
        input do
          key :age, type: :integer, domain: 18..65
          key :status, type: :string, domain: %w[active inactive]
        end
      end
    end

    it "formats range violation messages clearly" do
      expect do
        error_schema.from({ age: 17, status: "active" })
      end.to raise_error(Kumi::Core::Errors::InputValidationError, /Field :age value 17 is outside domain 18\.\.65/)
    end

    it "formats array violation messages clearly" do
      expect do
        error_schema.from({ age: 25, status: "unknown" })
      end.to raise_error(Kumi::Core::Errors::InputValidationError, /Field :status value "unknown" is not in allowed values/)
    end

    it "formats multiple violations with clear structure" do
      error = nil
      expect do
        error_schema.from({ age: 17, status: "unknown" })
      end.to raise_error(Kumi::Core::Errors::InputValidationError) { |e| error = e }

      message = error.message
      expect(message).to include("Domain violations:")
      expect(message).to include("- Field :age")
      expect(message).to include("- Field :status")
    end
  end

  describe "Backward compatibility" do
    it "works with existing schemas without domain constraints" do
      legacy_schema = create_schema do
        input do
          key :name, type: :string
          key :age, type: :integer
        end

        trait :adult, input.age, :>=, 18
      end

      expect do
        runner = legacy_schema.from({ name: "John", age: 25 })
        expect(runner[:adult]).to be true
      end.not_to raise_error
    end

    it "works with schemas using old key() syntax without domains" do
      # This test ensures we don't break existing code that doesn't use domains
      expect do
        simple_schema = create_schema do
          input do
            key :value, type: :integer
          end

          trait :always_true, input.value, :>, 0
        end

        runner = simple_schema.from({ value: 42 })
        expect(runner[:always_true]).to be true
      end.not_to raise_error
    end
  end
end
