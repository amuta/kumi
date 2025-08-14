# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kumi::Kernels::Ruby::StringScalar do
  describe ".str_concat" do
    it "concatenates two strings" do
      expect(described_class.str_concat("hello", "world")).to eq("helloworld")
    end

    it "concatenates with spaces" do
      expect(described_class.str_concat("hello ", "world")).to eq("hello world")
    end

    it "concatenates empty strings" do
      expect(described_class.str_concat("", "hello")).to eq("hello")
      expect(described_class.str_concat("hello", "")).to eq("hello")
      expect(described_class.str_concat("", "")).to eq("")
    end

    it "concatenates numbers as strings" do
      expect(described_class.str_concat(5, 3)).to eq("53")
      expect(described_class.str_concat("number: ", 42)).to eq("number: 42")
    end

    it "concatenates mixed types" do
      expect(described_class.str_concat("value: ", true)).to eq("value: true")
      expect(described_class.str_concat("pi: ", 3.14)).to eq("pi: 3.14")
    end

    it "handles nil values" do
      expect(described_class.str_concat("hello", nil)).to eq("hello")
      expect(described_class.str_concat(nil, "world")).to eq("world")
      expect(described_class.str_concat(nil, nil)).to eq("")
    end

    it "concatenates unicode strings" do
      expect(described_class.str_concat("こんにちは", "世界")).to eq("こんにちは世界")
      expect(described_class.str_concat("Hello ", "🌍")).to eq("Hello 🌍")
    end

    it "concatenates multiline strings" do
      str1 = "line1\nline2"
      str2 = "\nline3"
      expect(described_class.str_concat(str1, str2)).to eq("line1\nline2\nline3")
    end

    it "concatenates strings with special characters" do
      expect(described_class.str_concat("tab\there", "quote\"here")).to eq("tab\therequote\"here")
    end
  end

  describe ".str_length" do
    it "returns length of string" do
      expect(described_class.str_length("hello")).to eq(5)
    end

    it "returns length of empty string" do
      expect(described_class.str_length("")).to eq(0)
    end

    it "returns length of string with spaces" do
      expect(described_class.str_length("hello world")).to eq(11)
    end

    it "handles nil input" do
      expect(described_class.str_length(nil)).to be_nil
    end

    it "counts unicode characters correctly" do
      expect(described_class.str_length("こんにちは")).to eq(5)
      expect(described_class.str_length("🌍🌎🌏")).to eq(3)
    end

    it "counts newlines and special characters" do
      expect(described_class.str_length("line1\nline2")).to eq(11)
      expect(described_class.str_length("tab\there")).to eq(8)
      expect(described_class.str_length("quote\"here")).to eq(10)
    end

    it "handles very long strings" do
      long_string = "a" * 10000
      expect(described_class.str_length(long_string)).to eq(10000)
    end

    it "handles strings with only whitespace" do
      expect(described_class.str_length("   ")).to eq(3)
      expect(described_class.str_length("\t\n\r")).to eq(3)
    end
  end
end