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

  describe ".reset!" do
    before do
      # Set some instance variables to test reset
      Kumi.instance_variable_set(:@__syntax_tree__, "test_tree")
      Kumi.instance_variable_set(:@__analyzer_result__, "test_result")
      Kumi.instance_variable_set(:@__compiled_schema__, "test_schema")
      Kumi.instance_variable_set(:@__schema_metadata__, "test_metadata")
    end

    it "resets all schema-related instance variables" do
      Kumi.reset!

      expect(Kumi.instance_variable_get(:@__syntax_tree__)).to be_nil
      expect(Kumi.instance_variable_get(:@__analyzer_result__)).to be_nil
      expect(Kumi.instance_variable_get(:@__compiled_schema__)).to be_nil
      expect(Kumi.instance_variable_get(:@__schema_metadata__)).to be_nil
    end
  end

  describe ".inspector_from_schema" do
    context "when schema is defined" do
      before do
        Kumi.instance_variable_set(:@__syntax_tree__, "test_tree")
        Kumi.instance_variable_set(:@__analyzer_result__, "test_result")
        Kumi.instance_variable_set(:@__compiled_schema__, "test_schema")
      end

      after { Kumi.reset! }

      it "creates an Inspector with current schema state" do
        inspector = Kumi.inspector_from_schema

        expect(inspector).to be_a(Kumi::Schema::Inspector)
        expect(inspector.syntax_tree).to eq("test_tree")
        expect(inspector.analyzer_result).to eq("test_result")
        expect(inspector.compiled_schema).to eq("test_schema")
      end
    end
  end

  describe "autoloading" do
    it "autoloads core modules" do
      expect(defined?(Kumi::Core)).to be_truthy
    end
  end
end
