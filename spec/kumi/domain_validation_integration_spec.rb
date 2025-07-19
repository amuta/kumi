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

        predicate :adult, input.age, :>=, 18
        value :grade, fn(:conditional, fn(:>=, input.score, 90), "A", "B")
      end
    end

    context "with valid input" do
      it "creates runner successfully" do
        runner = schema.from({ age: 25, score: 85.0, status: "active" })
        
        expect(runner).to be_a(Kumi::Runner)
        expect(runner.fetch(:adult)).to be true
        expect(runner.fetch(:grade)).to eq("B")
      end

      it "accepts boundary values" do
        expect {
          schema.from({ age: 18, score: 0.0, status: "active" })
        }.not_to raise_error

        expect {
          schema.from({ age: 65, score: 100.0, status: "pending" })
        }.not_to raise_error
      end
    end

    context "with domain violations" do
      it "raises DomainViolationError for single violation" do
        expect {
          schema.from({ age: 17, score: 85.0, status: "active" })
        }.to raise_error(Kumi::Errors::InputValidationError) do |error|
          expect(error.single_violation?).to be true
          expect(error.violations.first[:field]).to eq(:age)
          expect(error.message).to include("Field :age value 17 is outside domain 18..65")
        end
      end

      it "raises DomainViolationError for multiple violations" do
        expect {
          schema.from({ age: 16, score: 110.0, status: "unknown" })
        }.to raise_error(Kumi::Errors::InputValidationError) do |error|
          expect(error.multiple_violations?).to be true
          expect(error.violations.size).to eq(3)
          
          fields = error.violations.map { |v| v[:field] }
          expect(fields).to contain_exactly(:age, :score, :status)
          
          expect(error.message).to include("Domain violations:")
          expect(error.message).to include("Field :age value 16")
          expect(error.message).to include("Field :score value 110.0")
          expect(error.message).to include("Field :status value \"unknown\"")
        end
      end

      it "provides detailed violation information" do
        expect {
          schema.from({ age: 70, score: 85.0, status: "active" })
        }.to raise_error(Kumi::Errors::InputValidationError) do |error|
          violation = error.violations.first
          expect(violation[:field]).to eq(:age)
          expect(violation[:value]).to eq(70)
          expect(violation[:domain]).to eq(18..65)
          expect(violation[:message]).to be_a(String)
        end
      end
    end

    context "with missing domain constraints" do
      let(:schema_no_domains) do
        create_schema do
          input do
            key :name, type: :string
            key :count, type: :integer
          end

          predicate :has_name, input.name, :!=, ""
        end
      end

      it "allows any values when no domains specified" do
        expect {
          runner = schema_no_domains.from({ name: "any name", count: 999999 })
          expect(runner.fetch(:has_name)).to be true
        }.not_to raise_error
      end
    end

    context "with mixed domain and no-domain fields" do
      let(:mixed_schema) do
        create_schema do
          input do
            key :name, type: :string              # no domain
            key :age, type: :integer, domain: 18..65  # has domain
            key :comment, type: :string            # no domain
          end

          value :display_name, input.name
        end
      end

      it "validates only fields with domains" do
        # This should work - age is valid, other fields have no constraints
        expect {
          mixed_schema.from({ name: "Any Name", age: 25, comment: "Any comment" })
        }.not_to raise_error

        # This should fail - age violates domain
        expect {
          mixed_schema.from({ name: "Any Name", age: 17, comment: "Any comment" })
        }.to raise_error(Kumi::Errors::InputValidationError)
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

          predicate :valid_email, input.email, :!=, ""
        end
      end

      it "validates using custom proc" do
        expect {
          email_schema.from({ email: "user@example.com" })
        }.not_to raise_error

        expect {
          email_schema.from({ email: "invalid-email" })
        }.to raise_error(Kumi::Errors::InputValidationError) do |error|
          expect(error.message).to include("does not satisfy custom domain constraint")
        end
      end
    end

    context "with exclusive ranges" do
      let(:probability_schema) do
        create_schema do
          input do
            key :probability, type: :float, domain: 0.0...1.0
          end

          predicate :likely, input.probability, :>, 0.5
        end
      end

      it "handles exclusive end correctly" do
        expect {
          probability_schema.from({ probability: 0.0 })
        }.not_to raise_error

        expect {
          probability_schema.from({ probability: 0.999 })
        }.not_to raise_error

        expect {
          probability_schema.from({ probability: 1.0 })
        }.to raise_error(Kumi::Errors::InputValidationError) do |error|
          expect(error.message).to include("(exclusive)")
        end
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
      expect {
        error_schema.from({ age: 17, status: "active" })
      }.to raise_error(Kumi::Errors::InputValidationError, /Field :age value 17 is outside domain 18\.\.65/)
    end

    it "formats array violation messages clearly" do
      expect {
        error_schema.from({ age: 25, status: "unknown" })
      }.to raise_error(Kumi::Errors::InputValidationError, /Field :status value "unknown" is not in allowed values/)
    end

    it "formats multiple violations with clear structure" do
      expect {
        error_schema.from({ age: 17, status: "unknown" })
      }.to raise_error(Kumi::Errors::InputValidationError) do |error|
        message = error.message
        expect(message).to include("Domain violations:")
        expect(message).to include("- Field :age")
        expect(message).to include("- Field :status")
      end
    end
  end

  describe "Backward compatibility" do
    it "works with existing schemas without domain constraints" do
      legacy_schema = create_schema do
        input do
          key :name, type: :string
          key :age, type: :integer
        end

        predicate :adult, input.age, :>=, 18
      end

      expect {
        runner = legacy_schema.from({ name: "John", age: 25 })
        expect(runner.fetch(:adult)).to be true
      }.not_to raise_error
    end

    it "works with schemas using old key() syntax without domains" do
      # This test ensures we don't break existing code that doesn't use domains
      expect {
        simple_schema = create_schema do
          input do
            key :value, type: :integer
          end
          
          predicate :always_true, input.value, :>, 0
        end
        
        runner = simple_schema.from({ value: 42 })
        expect(runner.fetch(:always_true)).to be true
      }.not_to raise_error
    end
  end
end