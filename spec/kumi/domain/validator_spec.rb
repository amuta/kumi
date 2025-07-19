# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kumi::Domain::Validator do
  describe ".validate_field" do
    context "with Range domains" do
      it "accepts values within inclusive range" do
        expect(described_class.validate_field(:age, 25, 18..65)).to be true
        expect(described_class.validate_field(:age, 18, 18..65)).to be true
        expect(described_class.validate_field(:age, 65, 18..65)).to be true
      end

      it "rejects values outside inclusive range" do
        expect(described_class.validate_field(:age, 17, 18..65)).to be false
        expect(described_class.validate_field(:age, 66, 18..65)).to be false
      end

      it "handles exclusive ranges correctly" do
        expect(described_class.validate_field(:score, 0.0, 0.0...1.0)).to be true
        expect(described_class.validate_field(:score, 0.5, 0.0...1.0)).to be true
        expect(described_class.validate_field(:score, 1.0, 0.0...1.0)).to be false
      end

      it "handles float ranges" do
        expect(described_class.validate_field(:price, 10.5, 0.0..100.0)).to be true
        expect(described_class.validate_field(:price, -0.1, 0.0..100.0)).to be false
      end
    end

    context "with Array domains" do
      it "accepts values in the array" do
        statuses = %w[active inactive pending]
        expect(described_class.validate_field(:status, "active", statuses)).to be true
        expect(described_class.validate_field(:status, "pending", statuses)).to be true
      end

      it "rejects values not in the array" do
        statuses = %w[active inactive pending]
        expect(described_class.validate_field(:status, "unknown", statuses)).to be false
        expect(described_class.validate_field(:status, "deleted", statuses)).to be false
      end

      it "handles symbol arrays" do
        roles = %i[admin user guest]
        expect(described_class.validate_field(:role, :admin, roles)).to be true
        expect(described_class.validate_field(:role, :superuser, roles)).to be false
      end
    end

    context "with Proc domains" do
      it "accepts values that satisfy the proc" do
        email_validator = ->(v) { v.match?(/\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i) }
        expect(described_class.validate_field(:email, "test@example.com", email_validator)).to be true
      end

      it "rejects values that don't satisfy the proc" do
        email_validator = ->(v) { v.match?(/\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i) }
        expect(described_class.validate_field(:email, "invalid-email", email_validator)).to be false
      end
    end

    context "with nil domain" do
      it "always returns true" do
        expect(described_class.validate_field(:anything, "any value", nil)).to be true
        expect(described_class.validate_field(:anything, 123, nil)).to be true
      end
    end

    context "with unknown domain types" do
      it "returns true by default" do
        expect(described_class.validate_field(:field, "value", "unknown")).to be true
        expect(described_class.validate_field(:field, 123, { custom: "constraint" })).to be true
      end
    end
  end

  describe ".validate_context" do
    let(:input_meta) do
      {
        age: { type: :integer, domain: 18..65 },
        score: { type: :float, domain: 0.0..100.0 },
        status: { type: :string, domain: %w[active inactive] },
        name: { type: :string, domain: nil }
      }
    end

    context "with valid input" do
      it "returns empty violations array" do
        context = { age: 25, score: 85.0, status: "active", name: "John" }
        violations = described_class.validate_context(context, input_meta)
        expect(violations).to be_empty
      end
    end

    context "with single violation" do
      it "returns violation details" do
        context = { age: 17, score: 85.0, status: "active" }
        violations = described_class.validate_context(context, input_meta)

        expect(violations.size).to eq(1)
        violation = violations.first
        expect(violation[:field]).to eq(:age)
        expect(violation[:value]).to eq(17)
        expect(violation[:domain]).to eq(18..65)
        expect(violation[:message]).to include("Field :age value 17 is outside domain 18..65")
      end
    end

    context "with multiple violations" do
      it "returns all violations" do
        context = { age: 17, score: 150.0, status: "unknown" }
        violations = described_class.validate_context(context, input_meta)

        expect(violations.size).to eq(3)
        fields = violations.map { |v| v[:field] }
        expect(fields).to contain_exactly(:age, :score, :status)
      end
    end

    context "with fields not in input_meta" do
      it "ignores extra fields" do
        context = { age: 25, extra_field: "ignored" }
        violations = described_class.validate_context(context, input_meta)
        expect(violations).to be_empty
      end
    end

    context "with fields without domains" do
      it "skips validation for fields without domains" do
        context = { name: "any name", age: 25 }
        violations = described_class.validate_context(context, input_meta)
        expect(violations).to be_empty
      end
    end
  end

  describe ".extract_domain_metadata" do
    let(:input_meta) do
      {
        age: { type: :integer, domain: 18..65 },
        score: { type: :float, domain: 0.0..100.0 },
        status: { type: :string, domain: %w[active inactive pending] },
        email: { type: :string, domain: ->(v) { v.include?("@") } },
        name: { type: :string, domain: nil }
      }
    end

    it "extracts metadata for all fields with domains" do
      metadata = described_class.extract_domain_metadata(input_meta)

      expect(metadata.keys).to contain_exactly(:age, :score, :status, :email)
      expect(metadata[:name]).to be_nil
    end

    context "for range domains" do
      it "provides comprehensive range metadata" do
        metadata = described_class.extract_domain_metadata(input_meta)
        age_meta = metadata[:age]

        expect(age_meta[:type]).to eq(:range)
        expect(age_meta[:min]).to eq(18)
        expect(age_meta[:max]).to eq(65)
        expect(age_meta[:exclusive_end]).to be false
        expect(age_meta[:size]).to eq(48) # 65-18+1
        expect(age_meta[:sample_values]).to include(18, 65)
        expect(age_meta[:boundary_values]).to eq([18, 65])
        expect(age_meta[:invalid_samples]).to include(17, 66)
      end

      it "handles exclusive ranges" do
        exclusive_meta = { score: { domain: 0.0...1.0 } }
        metadata = described_class.extract_domain_metadata(exclusive_meta)
        score_meta = metadata[:score]

        expect(score_meta[:exclusive_end]).to be true
        expect(score_meta[:invalid_samples]).to include(1.0)
      end

      it "handles large ranges" do
        large_meta = { id: { domain: 1..10_000 } }
        metadata = described_class.extract_domain_metadata(large_meta)

        expect(metadata[:id][:size]).to eq(:large)
      end

      it "handles continuous ranges" do
        float_meta = { temperature: { domain: -10.5..50.2 } }
        metadata = described_class.extract_domain_metadata(float_meta)

        expect(metadata[:temperature][:size]).to eq(:continuous)
      end
    end

    context "for enumeration domains" do
      it "provides enumeration metadata" do
        metadata = described_class.extract_domain_metadata(input_meta)
        status_meta = metadata[:status]

        expect(status_meta[:type]).to eq(:enumeration)
        expect(status_meta[:values]).to eq(%w[active inactive pending])
        expect(status_meta[:size]).to eq(3)
        expect(status_meta[:sample_values]).to be_a(Array)
        expect(status_meta[:invalid_samples]).to be_a(Array)
      end
    end

    context "for custom domains" do
      it "provides custom domain metadata" do
        metadata = described_class.extract_domain_metadata(input_meta)
        email_meta = metadata[:email]

        expect(email_meta[:type]).to eq(:custom)
        expect(email_meta[:description]).to eq("Custom constraint function")
      end
    end
  end
end
