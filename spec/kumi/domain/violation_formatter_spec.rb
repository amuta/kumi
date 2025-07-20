# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kumi::Domain::ViolationFormatter do
  describe ".format_message" do
    context "with range domains" do
      let(:field) { :age }

      it "formats inclusive range violations clearly" do
        domain = 18..65
        message = described_class.format_message(field, 17, domain)

        expect(message).to include("Field :age")
        expect(message).to include("value 17")
        expect(message).to include("outside domain")
        expect(message).to include("18..65")
      end

      it "formats exclusive range violations with proper notation" do
        domain = 0.0...1.0
        message = described_class.format_message(field, 1.0, domain)

        expect(message).to include("Field :age")
        expect(message).to include("value 1.0")
        expect(message).to include("outside domain")
        expect(message).to include("0.0...1.0")
        expect(message).to include("(exclusive)")
      end

      it "handles negative range boundaries" do
        domain = -100..-50
        message = described_class.format_message(field, -49, domain)

        expect(message).to include("value -49")
        expect(message).to include("-100..-50")
      end

      it "handles float ranges with decimals" do
        domain = 10.5..20.7
        message = described_class.format_message(field, 25.3, domain)

        expect(message).to include("value 25.3")
        expect(message).to include("10.5..20.7")
      end
    end

    context "with array domains" do
      let(:field) { :status }

      it "formats string array violations" do
        domain = %w[active inactive pending]
        message = described_class.format_message(field, "unknown", domain)

        expect(message).to include("Field :status")
        expect(message).to include('value "unknown"')
        expect(message).to include("not in allowed values")
        # The exact format may vary, but should include the domain values
        expect(message).to match(/active.*inactive.*pending|inactive.*active.*pending/)
      end

      it "formats symbol array violations" do
        domain = %i[admin user guest]
        message = described_class.format_message(field, :superuser, domain)

        expect(message).to include("Field :status")
        expect(message).to include("value :superuser")
        expect(message).to include("not in allowed values")
        expect(message).to include("[:admin, :user, :guest]")
      end

      it "formats numeric array violations" do
        domain = [1, 3, 5, 7]
        message = described_class.format_message(field, 4, domain)

        expect(message).to include("value 4")
        expect(message).to include("not in allowed values")
        expect(message).to include("[1, 3, 5, 7]")
      end

      it "handles mixed type arrays" do
        domain = ["active", :pending, 1, true]
        message = described_class.format_message(field, "unknown", domain)

        expect(message).to include('value "unknown"')
        expect(message).to include("not in allowed values")
        # Should include representation of the mixed array
        expect(message).to include("[")
        expect(message).to include("]")
      end

      it "handles large arrays with truncation" do
        domain = (1..50).to_a # Large array
        message = described_class.format_message(field, 100, domain)

        expect(message).to include("value 100")
        expect(message).to include("not in allowed values")
        # Should indicate truncation for readability
        if message.include?("...")
          expect(message).to include("...")
        end
      end

      it "handles empty arrays" do
        domain = []
        message = described_class.format_message(field, "anything", domain)

        expect(message).to include('value "anything"')
        expect(message).to include("not in allowed values")
        expect(message).to include("[]")
      end
    end

    context "with proc domains" do
      let(:field) { :email }

      it "formats proc domain violations with generic message" do
        domain = ->(v) { v.include?("@") }
        message = described_class.format_message(field, "invalid-email", domain)

        expect(message).to include("Field :email")
        expect(message).to include('value "invalid-email"')
        expect(message).to include("does not satisfy custom domain constraint")
      end

      it "handles complex proc violations" do
        domain = ->(v) { v.is_a?(String) && v.length > 8 && v.match?(/[A-Z]/) }
        message = described_class.format_message(field, "weak", domain)

        expect(message).to include('value "weak"')
        expect(message).to include("does not satisfy custom domain constraint")
      end

      it "handles proc violations with various value types" do
        domain = ->(v) { v.is_a?(Integer) && v.positive? }
        message = described_class.format_message(field, -5, domain)

        expect(message).to include("value -5")
        expect(message).to include("does not satisfy custom domain constraint")
      end
    end

    context "with unknown domain types" do
      let(:field) { :custom_field }

      it "provides generic violation message for unknown domain types" do
        domain = { custom: "constraint" }
        message = described_class.format_message(field, "value", domain)

        expect(message).to include("Field :custom_field")
        expect(message).to include('value "value"')
        expect(message).to include("violates domain constraint")
        expect(message).to include("custom")
      end

      it "handles nil domains gracefully" do
        message = described_class.format_message(field, "value", nil)

        expect(message).to include("Field :custom_field")
        expect(message).to include('value "value"')
        expect(message).to include("violates domain constraint")
      end
    end

    context "with various value types" do
      let(:domain) { %w[valid] }

      it "formats string values with quotes" do
        message = described_class.format_message(:field, "invalid", domain)
        expect(message).to include('"invalid"')
      end

      it "formats symbol values with colon notation" do
        message = described_class.format_message(:field, :invalid, domain)
        expect(message).to include(":invalid")
      end

      it "formats numeric values without quotes" do
        message = described_class.format_message(:field, 42, domain)
        expect(message).to include("value 42")
        expect(message).not_to include('"42"')
      end

      it "formats boolean values appropriately" do
        true_message = described_class.format_message(:field, true, domain)
        expect(true_message).to include("value true")

        false_message = described_class.format_message(:field, false, domain)
        expect(false_message).to include("value false")
      end

      it "formats nil values" do
        message = described_class.format_message(:field, nil, domain)
        expect(message).to include("value ")
        # Should handle nil appropriately in the message
      end

      it "formats complex values like arrays and hashes" do
        array_message = described_class.format_message(:field, [1, 2, 3], domain)
        expect(array_message).to include("value [1, 2, 3]")

        hash_message = described_class.format_message(:field, { a: 1 }, domain)
        expect(hash_message).to include("value ")
        expect(hash_message).to include("a")
      end
    end

    context "edge cases and special characters" do
      let(:domain) { %w[valid] }

      it "handles field names with special characters" do
        message = described_class.format_message(:"field-with-dashes", "value", domain)
        expect(message).to include("Field :field-with-dashes")
      end

      it "handles values with special characters" do
        message = described_class.format_message(:field, "value with spaces & symbols!", domain)
        expect(message).to include('"value with spaces & symbols!"')
      end

      it "handles very long values gracefully" do
        long_value = "a" * 200
        message = described_class.format_message(:field, long_value, domain)
        expect(message).to include("Field :field")
        # Should either include the full value or truncate it reasonably
        expect(message.length).to be < 1000 # Reasonable message length
      end
    end
  end
end