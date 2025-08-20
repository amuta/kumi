# frozen_string_literal: true

require 'stringio'

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
      expect(described_class.print({a: 1, b: 2})).to eq("{:a: 1, :b: 2}")
      expect(described_class.print(Set.new([1, 2, 3]))).to eq("Set[1, 2, 3]")
    end

    it "raises for unhandled types" do
      custom_struct = Struct.new(:name).new("test")
      
      expect {
        described_class.print(custom_struct)
      }.to raise_error(/No printer defined for/)
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

    it "detects any unhandled object inspection strings in debug output" do
      # Run a complex schema to generate debug output
      schema_module.schema do
        input do
          string :name
          array :items do
            float :price
            string :category
          end
          hash :metadata, key: { type: :string }, val: { type: :any }
        end
        
        trait :expensive, fn(:any?, input.items.price > 100.0)
        trait :electronics, fn(:any?, input.items.category == "electronics")
        
        value :greeting, fn(:concat, "Hello ", input.name)
        value :total, fn(:sum, input.items.price)
        
        value :labels do
          on expensive, electronics, "Premium Tech"
          on expensive, "Premium"
          base "Standard"
        end
      end

      debug_output = @captured_output.string
      
      # Look for any object inspection strings that start with #<
      object_inspections = debug_output.scan(/#<[^>]+>/)
      
      if object_inspections.any?
        unique_patterns = object_inspections.uniq.first(10) # Show first 10 unique patterns
        
        fail <<~ERROR
          Found #{object_inspections.size} unhandled object inspection strings in debug output!
          
          This means there are object types that don't have explicit printers defined.
          Please add printer handlers for these types in DebugPrinters.
          
          Sample patterns found:
          #{unique_patterns.map { |pattern| "  - #{pattern}" }.join("\n")}
          
          To fix this:
          1. Identify the object classes from these inspection strings
          2. Add explicit `when ObjectClass then print_object_class(obj)` cases to DebugPrinters
          3. Add corresponding private printer methods
          
          This ensures debug output remains clean and readable!
        ERROR
      end
    end

    it "handles complex schemas without object inspection leakage" do
      # This test will pass once all object types have explicit printers
      schema_module.schema do
        input do
          array :orders do
            float :amount
            string :status
            hash :details, key: { type: :string }, val: { type: :any }
          end
        end
        
        trait :large_orders, fn(:any?, input.orders.amount > 1000.0)
        trait :pending_orders, fn(:any?, input.orders.status == "pending")
        
        value :order_summary do
          on large_orders, pending_orders, "Large Pending Orders"
          on large_orders, "Large Orders"
          on pending_orders, "Pending Orders"
          base "Regular Orders"
        end
        
        value :total_amount, fn(:sum, input.orders.amount)
      end

      debug_output = @captured_output.string
      
      # This should find no object inspection strings if all printers are defined
      object_inspections = debug_output.scan(/#<[^>]+>/)
      
      expect(object_inspections).to be_empty, 
        "Found #{object_inspections.size} object inspection strings. All object types should have explicit printers!"
    end
  end
end