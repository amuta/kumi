# frozen_string_literal: true

require "stringio"

RSpec.describe "Analyzer Debug Integration" do
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

  it "captures debug events during real schema compilation" do
    schema_module.schema do
      input do
        integer :x
        integer :y
      end

      value :sum, input.x + input.y
      value :double_sum, fn(:multiply, ref(:sum), 2)
    end

    debug_output = @captured_output.string

    # Verify that debug output was generated
    expect(debug_output).to include("=== STATE")
    expect(debug_output).to include("NameIndexer")
    expect(debug_output).to include("TypeChecker")
    expect(debug_output).to include("LowerToIRPass")

    # Verify structure - just check that we have the expected patterns
    expect(debug_output).to include('"ts":')
    expect(debug_output).to include('"pass":')
    expect(debug_output).to include('"elapsed_ms":')
    expect(debug_output).to include('"diff":')
    expect(debug_output).to include('"logs":')

    # Verify we have multiple passes by counting occurrences
    pass_count = debug_output.scan(/"pass": "[^"]*"/).size
    expect(pass_count).to be >= 10
  end

  it "tracks state changes across passes correctly" do
    schema_module.schema do
      input do
        string :name
      end

      value :greeting, fn(:concat, "Hello, ", input.name)
    end

    debug_output = @captured_output.string

    # Look for key state additions
    expect(debug_output).to include('"type": "added"')
    expect(debug_output).to include('"declarations"')
    expect(debug_output).to include('"input_metadata"')
    expect(debug_output).to include('"evaluation_order"')
    expect(debug_output).to include('"ir_module"')
  end

  it "includes timing information for all passes" do
    schema_module.schema do
      input do
        array :items do
          float :price
          integer :quantity
        end
      end

      value :subtotals, fn(:multiply, input.items.price, input.items.quantity)
      value :total, fn(:sum, ref(:subtotals))
    end

    debug_output = @captured_output.string

    # Extract all timing information
    timing_lines = debug_output.scan(/=== STATE (\w+) \(([0-9.]+)ms\) ===/)

    expect(timing_lines.size).to be >= 10 # Should have multiple passes

    # Verify all timings are non-negative numbers
    timing_lines.each do |pass_name, timing|
      expect(timing.to_f).to be >= 0
      expect(pass_name).to match(/\A[A-Z][a-zA-Z]*\z/) # Valid pass name format
    end
  end

  context "with file output configured" do
    let(:temp_file) { "/tmp/debug_integration_test.log" }

    around do |example|
      original_path = ENV.fetch("KUMI_DEBUG_OUTPUT_PATH", nil)
      ENV["KUMI_DEBUG_OUTPUT_PATH"] = temp_file

      # Clean up any existing file
      File.delete(temp_file) if File.exist?(temp_file)

      example.run

      ENV["KUMI_DEBUG_OUTPUT_PATH"] = original_path
      File.delete(temp_file) if File.exist?(temp_file)
    end

    it "writes debug events to specified file" do
      schema_module.schema do
        input do
          integer :value
        end

        value :doubled, fn(:multiply, input.value, 2)
      end

      expect(File.exist?(temp_file)).to be true

      file_content = File.read(temp_file)
      lines = file_content.strip.split("\n")

      # Each line should be valid JSON
      lines.each do |line|
        event = JSON.parse(line)
        expect(event).to include("ts", "pass", "elapsed_ms", "diff", "logs")
      end

      # Should have events for multiple passes
      expect(lines.size).to be >= 10
    end
  end

  context "when disabled" do
    around do |example|
      ENV["KUMI_DEBUG_STATE"] = "0"
      example.run
    end

    it "produces no debug output when disabled" do
      schema_module.schema do
        input do
          integer :x
        end

        value :result, fn(:add, input.x, 1)
      end

      debug_output = @captured_output.string
      expect(debug_output).to be_empty
    end
  end

  it "handles complex schemas with cascades and arrays" do
    schema_module.schema do
      input do
        array :orders do
          float :amount
          string :status
        end
      end

      trait :is_large, fn(:>, input.orders.amount, 100.0)
      trait :is_pending, fn(:==, input.orders.status, "pending")

      value :order_types do
        on is_large, is_pending, "Large Pending"
        on is_large, "Large"
        on is_pending, "Pending"
        base "Standard"
      end
    end

    debug_output = @captured_output.string

    # Should include broadcast detection and cascade analysis
    expect(debug_output).to include("BroadcastDetector")
    expect(debug_output).to include("UnsatDetector")
    expect(debug_output).to include("ScopeResolutionPass")
  end
end
