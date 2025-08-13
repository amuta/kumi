# frozen_string_literal: true

RSpec.describe Kumi do
  describe "module setup" do
    it "has a version number" do
      expect(Kumi::VERSION).not_to be_nil
      expect(Kumi::VERSION).to be_a(String)
      expect(Kumi::VERSION).to match(/^\d+\.\d+\.\d+/)
    end

    it "loads with Zeitwerk" do
      expect(defined?(Zeitwerk)).to be_truthy
    end
  end

  describe "autoloading" do
    it "autoloads core modules" do
      expect(defined?(Kumi::Core)).to be_truthy
    end
  end
end
