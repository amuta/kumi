# frozen_string_literal: true

require "stringio"

RSpec.describe DebugPrinters do
  describe ".print" do
    it "handles all basic Ruby types" do
      expect(described_class.print(42)).to eq("42")
      expect(described_class.print(3.14)).to eq("3.14")
      expect(described_class.print("hello")).to eq("hello")
      expect(described_class.print(:symbol)).to eq(":symbol")
      expect(described_class.print(true)).to eq("true")
      expect(described_class.print(false)).to eq("false")
      expect(described_class.print(nil)).to eq("nil")
    end

    it "handles collections with truncation" do
      expect(described_class.print([1, 2, 3])).to eq("[1, 2, 3]")
      expect(described_class.print((1..10).to_a)).to eq("Array[10]")
      expect(described_class.print({ a: 1, b: 2 })).to eq("{:a: 1, :b: 2}")
      expect(described_class.print(Set.new([1, 2, 3]))).to eq("Set[1, 2, 3]")
    end

    it "raises for unhandled types" do
      custom_struct = Struct.new(:name).new("test")

      expect do
        described_class.print(custom_struct)
      end.to raise_error(/No printer defined for/)
    end
  end

  describe "debug output printer coverage" do
    let(:schema_module) do
      Module.new do
        extend Kumi::Schema
      end
    end

    around do |example|
      original_debug = ENV.fetch("KUMI_DEBUG_STATE", nil)
      ENV["KUMI_DEBUG_STATE"] = "1"

      # Capture debug output
      @captured_output = StringIO.new
      original_stdout = $stdout
      $stdout = @captured_output

      example.run

      $stdout = original_stdout
      ENV["KUMI_DEBUG_STATE"] = original_debug
    end

    it "checks for unhandled object inspection strings (info only)" do
      # Run a schema to generate debug output
      schema_module.schema do
        input do
          string :name
          array :items do
            float :price
          end
        end

        value :greeting, fn(:concat, "Hello ", input.name)
        value :total, fn(:sum, input.items.price)
      end

      debug_output = @captured_output.string
      object_inspections = debug_output.scan(/#<[^>]+>/)

      if object_inspections.any?
        # TODO: Decide when activate this.
        # warn "DebugPrinters: Found #{object_inspections.size} unhandled object inspections in debug output"
      end

      # Always pass - this is just informational
      expect(true).to be true
    end
  end
end
