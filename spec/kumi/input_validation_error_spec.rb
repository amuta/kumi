# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kumi::Errors::InputValidationError do
  describe "single violation" do
    context "with type violation" do
      let(:violation) do
        {
          type: :type_violation,
          field: :age,
          value: "25",
          expected_type: :integer,
          actual_type: :string,
          message: "Field :age expected integer, got \"25\" of type string"
        }
      end

      let(:error) { described_class.new([violation]) }

      it "reports single violation" do
        expect(error.single_violation?).to be true
        expect(error.multiple_violations?).to be false
      end

      it "categorizes violation correctly" do
        expect(error.has_type_violations?).to be true
        expect(error.has_domain_violations?).to be false
        expect(error.type_violations.size).to eq(1)
        expect(error.domain_violations.size).to eq(0)
      end

      it "formats single violation message" do
        expect(error.message).to eq("Field :age expected integer, got \"25\" of type string")
      end
    end

    context "with domain violation" do
      let(:violation) do
        {
          type: :domain_violation,
          field: :age,
          value: 16,
          domain: 18..65,
          message: "Field :age value 16 is outside domain 18..65"
        }
      end

      let(:error) { described_class.new([violation]) }

      it "categorizes violation correctly" do
        expect(error.has_type_violations?).to be false
        expect(error.has_domain_violations?).to be true
        expect(error.type_violations.size).to eq(0)
        expect(error.domain_violations.size).to eq(1)
      end

      it "formats single violation message" do
        expect(error.message).to eq("Field :age value 16 is outside domain 18..65")
      end
    end
  end

  describe "multiple violations" do
    context "with only type violations" do
      let(:violations) do
        [
          {
            type: :type_violation,
            field: :age,
            value: "25",
            expected_type: :integer,
            actual_type: :string,
            message: "Field :age expected integer, got \"25\" of type string"
          },
          {
            type: :type_violation,
            field: :active,
            value: "true",
            expected_type: :boolean,
            actual_type: :string,
            message: "Field :active expected boolean, got \"true\" of type string"
          }
        ]
      end

      let(:error) { described_class.new(violations) }

      it "reports multiple violations" do
        expect(error.single_violation?).to be false
        expect(error.multiple_violations?).to be true
      end

      it "categorizes violations correctly" do
        expect(error.has_type_violations?).to be true
        expect(error.has_domain_violations?).to be false
        expect(error.type_violations.size).to eq(2)
        expect(error.domain_violations.size).to eq(0)
      end

      it "formats type violations message" do
        message = error.message
        expect(message).to include("Type violations:")
        expect(message).to include("- Field :age expected integer")
        expect(message).to include("- Field :active expected boolean")
        expect(message).not_to include("Domain violations:")
      end
    end

    context "with only domain violations" do
      let(:violations) do
        [
          {
            type: :domain_violation,
            field: :age,
            value: 16,
            domain: 18..65,
            message: "Field :age value 16 is outside domain 18..65"
          },
          {
            type: :domain_violation,
            field: :score,
            value: 110.0,
            domain: 0.0..100.0,
            message: "Field :score value 110.0 is outside domain 0.0..100.0"
          }
        ]
      end

      let(:error) { described_class.new(violations) }

      it "categorizes violations correctly" do
        expect(error.has_type_violations?).to be false
        expect(error.has_domain_violations?).to be true
        expect(error.type_violations.size).to eq(0)
        expect(error.domain_violations.size).to eq(2)
      end

      it "formats domain violations message" do
        message = error.message
        expect(message).to include("Domain violations:")
        expect(message).to include("- Field :age value 16")
        expect(message).to include("- Field :score value 110.0")
        expect(message).not_to include("Type violations:")
      end
    end

    context "with mixed type and domain violations" do
      let(:violations) do
        [
          {
            type: :type_violation,
            field: :name,
            value: 12_345,
            expected_type: :string,
            actual_type: :integer,
            message: "Field :name expected string, got 12345 of type integer"
          },
          {
            type: :domain_violation,
            field: :age,
            value: 16,
            domain: 18..65,
            message: "Field :age value 16 is outside domain 18..65"
          }
        ]
      end

      let(:error) { described_class.new(violations) }

      it "categorizes violations correctly" do
        expect(error.has_type_violations?).to be true
        expect(error.has_domain_violations?).to be true
        expect(error.type_violations.size).to eq(1)
        expect(error.domain_violations.size).to eq(1)
      end

      it "formats mixed violations message with clear sections" do
        message = error.message
        expect(message).to include("Type violations:")
        expect(message).to include("- Field :name expected string")
        expect(message).to include("Domain violations:")
        expect(message).to include("- Field :age value 16")

        # Check order: type violations should come first
        type_index = message.index("Type violations:")
        domain_index = message.index("Domain violations:")
        expect(type_index).to be < domain_index
      end
    end
  end

  describe "violation accessors" do
    let(:violations) do
      [
        {
          type: :type_violation,
          field: :name,
          value: 123,
          expected_type: :string,
          actual_type: :integer,
          message: "Type error"
        },
        {
          type: :domain_violation,
          field: :age,
          value: 16,
          domain: 18..65,
          message: "Domain error"
        },
        {
          type: :type_violation,
          field: :active,
          value: "true",
          expected_type: :boolean,
          actual_type: :string,
          message: "Another type error"
        }
      ]
    end

    let(:error) { described_class.new(violations) }

    it "provides access to all violations" do
      expect(error.violations.size).to eq(3)
    end

    it "filters type violations" do
      type_violations = error.type_violations
      expect(type_violations.size).to eq(2)
      expect(type_violations.map { |v| v[:field] }).to contain_exactly(:name, :active)
    end

    it "filters domain violations" do
      domain_violations = error.domain_violations
      expect(domain_violations.size).to eq(1)
      expect(domain_violations.first[:field]).to eq(:age)
    end
  end
end
