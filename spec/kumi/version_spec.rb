# frozen_string_literal: true

RSpec.describe Kumi::VERSION do
  describe "version constant" do
    it "is defined" do
      expect(defined?(Kumi::VERSION)).to be_truthy
    end

    it "is a string" do
      expect(Kumi::VERSION).to be_a(String)
    end

    it "follows semantic versioning format" do
      expect(Kumi::VERSION).to match(/^\d+\.\d+\.\d+([.-].+)?$/)
    end

    it "is not empty" do
      expect(Kumi::VERSION).not_to be_empty
    end

    it "has current version" do
      expect(Kumi::VERSION).to be_a(String)
    end
  end

  describe "version parsing" do
    let(:version_parts) { Kumi::VERSION.split(".") }

    it "has major version" do
      expect(version_parts[0]).to match(/^\d+$/)
      expect(version_parts[0].to_i).to be >= 0
    end

    it "has minor version" do
      expect(version_parts[1]).to match(/^\d+$/)
      expect(version_parts[1].to_i).to be >= 0
    end

    it "has patch version" do
      expect(version_parts[2]).to match(/^\d+/)
      expect(version_parts[2].to_i).to be >= 0
    end
  end
end
