# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kumi::Input::ViolationCreator do
  describe ".create_type_violation" do
    context "with basic type mismatches" do
      it "creates violation for string expected, integer provided" do
        violation = described_class.create_type_violation(:name, 123, :string)

        expect(violation[:type]).to eq(:type_violation)
        expect(violation[:field]).to eq(:name)
        expect(violation[:value]).to eq(123)
        expect(violation[:expected_type]).to eq(:string)
        expect(violation[:actual_type]).to eq(:integer)
        expect(violation[:message]).to include("Field :name")
        expect(violation[:message]).to include("expected string")
        expect(violation[:message]).to include("got 123")
        expect(violation[:message]).to include("of type integer")
      end

      it "creates violation for integer expected, string provided" do
        violation = described_class.create_type_violation(:age, "25", :integer)

        expect(violation[:type]).to eq(:type_violation)
        expect(violation[:field]).to eq(:age)
        expect(violation[:value]).to eq("25")
        expect(violation[:expected_type]).to eq(:integer)
        expect(violation[:actual_type]).to eq(:string)
        expect(violation[:message]).to include("Field :age")
        expect(violation[:message]).to include("expected integer")
        expect(violation[:message]).to include('got "25"')
        expect(violation[:message]).to include("of type string")
      end

      it "creates violation for boolean expected, string provided" do
        violation = described_class.create_type_violation(:active, "true", :boolean)

        expect(violation[:type]).to eq(:type_violation)
        expect(violation[:field]).to eq(:active)
        expect(violation[:value]).to eq("true")
        expect(violation[:expected_type]).to eq(:boolean)
        expect(violation[:actual_type]).to eq(:string)
        expect(violation[:message]).to include("expected boolean")
        expect(violation[:message]).to include('got "true"')
      end

      it "creates violation for float expected, string provided" do
        violation = described_class.create_type_violation(:score, "85.5", :float)

        expect(violation[:type]).to eq(:type_violation)
        expect(violation[:field]).to eq(:score)
        expect(violation[:value]).to eq("85.5")
        expect(violation[:expected_type]).to eq(:float)
        expect(violation[:actual_type]).to eq(:string)
        expect(violation[:message]).to include("expected float")
      end
    end

    context "with complex type mismatches" do
      it "creates violation for array type mismatch" do
        expected_type = { array: :string }
        violation = described_class.create_type_violation(:tags, ["tag1", 123, "tag3"], expected_type)

        expect(violation[:type]).to eq(:type_violation)
        expect(violation[:field]).to eq(:tags)
        expect(violation[:value]).to eq(["tag1", 123, "tag3"])
        expect(violation[:expected_type]).to eq(expected_type)
        expect(violation[:actual_type]).to eq({ array: :mixed })
        expect(violation[:message]).to include("Field :tags")
        expect(violation[:message]).to include("expected array(string)")
        expect(violation[:message]).to include("of type array(mixed)")
      end

      it "creates violation for hash type mismatch" do
        expected_type = { hash: %i[string integer] }
        violation = described_class.create_type_violation(:metadata, { symbol: "value" }, expected_type)

        expect(violation[:type]).to eq(:type_violation)
        expect(violation[:field]).to eq(:metadata)
        expect(violation[:value]).to eq({ symbol: "value" })
        expect(violation[:expected_type]).to eq(expected_type)
        expect(violation[:actual_type]).to eq({ hash: %i[mixed mixed] })
        expect(violation[:message]).to include("expected hash(string, integer)")
        expect(violation[:message]).to include("of type hash(mixed, mixed)")
      end

      it "creates violation when non-array provided for array type" do
        expected_type = { array: :string }
        violation = described_class.create_type_violation(:tags, "not_an_array", expected_type)

        expect(violation[:type]).to eq(:type_violation)
        expect(violation[:field]).to eq(:tags)
        expect(violation[:value]).to eq("not_an_array")
        expect(violation[:expected_type]).to eq(expected_type)
        expect(violation[:actual_type]).to eq(:string)
        expect(violation[:message]).to include("expected array(string)")
        expect(violation[:message]).to include("of type string")
      end

      it "creates violation when non-hash provided for hash type" do
        expected_type = { hash: %i[string any] }
        violation = described_class.create_type_violation(:metadata, "not_a_hash", expected_type)

        expect(violation[:type]).to eq(:type_violation)
        expect(violation[:field]).to eq(:metadata)
        expect(violation[:value]).to eq("not_a_hash")
        expect(violation[:expected_type]).to eq(expected_type)
        expect(violation[:actual_type]).to eq(:string)
        expect(violation[:message]).to include("expected hash(string, any)")
        expect(violation[:message]).to include("of type string")
      end
    end

    context "with special values" do
      it "creates violation for nil value" do
        violation = described_class.create_type_violation(:required_field, nil, :string)

        expect(violation[:value]).to be_nil
        expect(violation[:actual_type]).to eq(:unknown)
        expect(violation[:message]).to include("got nil")
      end

      it "creates violation for symbol value" do
        violation = described_class.create_type_violation(:field, :symbol_value, :string)

        expect(violation[:value]).to eq(:symbol_value)
        expect(violation[:actual_type]).to eq(:symbol)
        expect(violation[:message]).to include("got :symbol_value")
        expect(violation[:message]).to include("of type symbol")
      end

      it "creates violation for boolean values" do
        true_violation = described_class.create_type_violation(:field, true, :string)
        expect(true_violation[:actual_type]).to eq(:boolean)
        expect(true_violation[:message]).to include("got true")

        false_violation = described_class.create_type_violation(:field, false, :string)
        expect(false_violation[:actual_type]).to eq(:boolean)
        expect(false_violation[:message]).to include("got false")
      end
    end

    context "with field name variations" do
      it "handles field names with underscores" do
        violation = described_class.create_type_violation(:user_name, 123, :string)
        expect(violation[:message]).to include("Field :user_name")
      end

      it "handles field names with numbers" do
        violation = described_class.create_type_violation(:field_1, 123, :string)
        expect(violation[:message]).to include("Field :field_1")
      end

      it "handles field names with special characters" do
        violation = described_class.create_type_violation(:"field-with-dashes", 123, :string)
        expect(violation[:message]).to include("Field :field-with-dashes")
      end
    end
  end

  describe ".create_domain_violation" do
    context "with range domains" do
      it "creates violation for value outside range" do
        violation = described_class.create_domain_violation(:age, 17, 18..65)

        expect(violation[:type]).to eq(:domain_violation)
        expect(violation[:field]).to eq(:age)
        expect(violation[:value]).to eq(17)
        expect(violation[:domain]).to eq(18..65)
        expect(violation[:message]).to be_a(String)
        expect(violation[:message]).to include("Field :age")
        expect(violation[:message]).to include("value 17")
      end

      it "creates violation for exclusive range" do
        violation = described_class.create_domain_violation(:probability, 1.0, 0.0...1.0)

        expect(violation[:type]).to eq(:domain_violation)
        expect(violation[:field]).to eq(:probability)
        expect(violation[:value]).to eq(1.0)
        expect(violation[:domain]).to eq(0.0...1.0)
        expect(violation[:message]).to include("Field :probability")
        expect(violation[:message]).to include("value 1.0")
      end
    end

    context "with array domains" do
      it "creates violation for value not in array" do
        domain = %w[active inactive pending]
        violation = described_class.create_domain_violation(:status, "unknown", domain)

        expect(violation[:type]).to eq(:domain_violation)
        expect(violation[:field]).to eq(:status)
        expect(violation[:value]).to eq("unknown")
        expect(violation[:domain]).to eq(domain)
        expect(violation[:message]).to include("Field :status")
        expect(violation[:message]).to include('value "unknown"')
      end

      it "creates violation for symbol not in symbol array" do
        domain = %i[admin user guest]
        violation = described_class.create_domain_violation(:role, :superuser, domain)

        expect(violation[:type]).to eq(:domain_violation)
        expect(violation[:field]).to eq(:role)
        expect(violation[:value]).to eq(:superuser)
        expect(violation[:domain]).to eq(domain)
        expect(violation[:message]).to include("Field :role")
        expect(violation[:message]).to include("value :superuser")
      end
    end

    context "with proc domains" do
      it "creates violation for proc that returns false" do
        email_proc = ->(v) { v.include?("@") }
        violation = described_class.create_domain_violation(:email, "invalid-email", email_proc)

        expect(violation[:type]).to eq(:domain_violation)
        expect(violation[:field]).to eq(:email)
        expect(violation[:value]).to eq("invalid-email")
        expect(violation[:domain]).to eq(email_proc)
        expect(violation[:message]).to include("Field :email")
        expect(violation[:message]).to include('value "invalid-email"')
        expect(violation[:message]).to include("custom domain constraint")
      end

      it "creates violation for complex proc domain" do
        complex_proc = ->(v) { v.is_a?(String) && v.length > 8 }
        violation = described_class.create_domain_violation(:password, "short", complex_proc)

        expect(violation[:type]).to eq(:domain_violation)
        expect(violation[:field]).to eq(:password)
        expect(violation[:value]).to eq("short")
        expect(violation[:domain]).to eq(complex_proc)
        expect(violation[:message]).to include("custom domain constraint")
      end
    end

    context "with various value types" do
      let(:domain) { %w[valid] }

      it "handles string values appropriately" do
        violation = described_class.create_domain_violation(:field, "invalid", domain)
        expect(violation[:message]).to include('"invalid"')
      end

      it "handles numeric values appropriately" do
        violation = described_class.create_domain_violation(:field, 42, domain)
        expect(violation[:message]).to include("value 42")
        expect(violation[:message]).not_to include('"42"')
      end

      it "handles boolean values appropriately" do
        true_violation = described_class.create_domain_violation(:field, true, domain)
        expect(true_violation[:message]).to include("value true")

        false_violation = described_class.create_domain_violation(:field, false, domain)
        expect(false_violation[:message]).to include("value false")
      end

      it "handles nil values appropriately" do
        violation = described_class.create_domain_violation(:field, nil, domain)
        expect(violation[:value]).to be_nil
        expect(violation[:message]).to include("Field :field")
      end

      it "handles complex values like arrays and hashes" do
        array_violation = described_class.create_domain_violation(:field, [1, 2, 3], domain)
        expect(array_violation[:value]).to eq([1, 2, 3])
        expect(array_violation[:message]).to include("Field :field")

        hash_violation = described_class.create_domain_violation(:field, { a: 1 }, domain)
        expect(hash_violation[:value]).to eq({ a: 1 })
        expect(hash_violation[:message]).to include("Field :field")
      end
    end

    context "error handling and delegation" do
      it "delegates message formatting to ViolationFormatter" do
        # This test verifies that the method properly delegates to the formatter
        # without testing the formatter's implementation details
        violation = described_class.create_domain_violation(:test_field, "test_value", %w[allowed])

        expect(violation[:message]).to be_a(String)
        expect(violation[:message]).to include("Field :test_field")
        expect(violation[:message]).to include("test_value")
      end

      it "handles formatter errors gracefully" do
        # Test with potentially problematic domain that might cause formatter issues
        violation = described_class.create_domain_violation(:field, "value", nil)

        expect(violation[:type]).to eq(:domain_violation)
        expect(violation[:field]).to eq(:field)
        expect(violation[:value]).to eq("value")
        expect(violation[:domain]).to be_nil
        expect(violation[:message]).to be_a(String)
      end
    end
  end

  describe "violation structure consistency" do
    it "ensures type violations have consistent structure" do
      violation = described_class.create_type_violation(:field, "value", :integer)

      expect(violation.keys).to contain_exactly(:type, :field, :value, :expected_type, :actual_type, :message)
      expect(violation[:type]).to eq(:type_violation)
      expect(violation[:field]).to be_a(Symbol)
      expect(violation[:value]).to be_a(String)
      expect(violation[:expected_type]).to be_a(Symbol)
      expect(violation[:actual_type]).to be_a(Symbol)
      expect(violation[:message]).to be_a(String)
    end

    it "ensures domain violations have consistent structure" do
      violation = described_class.create_domain_violation(:field, "value", %w[allowed])

      expect(violation.keys).to contain_exactly(:type, :field, :value, :domain, :message)
      expect(violation[:type]).to eq(:domain_violation)
      expect(violation[:field]).to be_a(Symbol)
      expect(violation[:value]).to be_a(String)
      expect(violation[:domain]).to be_a(Array)
      expect(violation[:message]).to be_a(String)
    end
  end
end
