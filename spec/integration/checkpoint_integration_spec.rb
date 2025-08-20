# frozen_string_literal: true

require "tmpdir"
require "fileutils"

RSpec.describe "Checkpoint Integration" do
  let(:temp_dir) { Dir.mktmpdir("checkpoint_integration") }

  around do |example|
    # Clean ENV
    original_env = ENV.select { |k, _| k.start_with?("KUMI_") }
    ENV.keys.select { |k| k.start_with?("KUMI_") }.each { |k| ENV.delete(k) }
    
    example.run
    
    # Restore ENV
    ENV.keys.select { |k| k.start_with?("KUMI_") }.each { |k| ENV.delete(k) }
    original_env.each { |k, v| ENV[k] = v }
    
    FileUtils.rm_rf(temp_dir) if Dir.exist?(temp_dir)
  end

  it "produces identical results when resuming from any checkpoint" do
    # First run: create a complete schema and capture the final result
    ENV["KUMI_CHECKPOINT"] = "1"
    ENV["KUMI_CHECKPOINT_DIR"] = temp_dir
    ENV["KUMI_CHECKPOINT_FORMAT"] = "marshal"
    
    schema_class = Module.new do
      extend Kumi::Schema
      
      schema do
        input do
          array :items do
            float :price
            integer :quantity
          end
          float :tax_rate
        end
        
        value :subtotals, input.items.price * input.items.quantity
        value :total_before_tax, fn(:sum, ref(:subtotals))
        value :tax_amount, ref(:total_before_tax) * input.tax_rate
        value :final_total, ref(:total_before_tax) + ref(:tax_amount)
      end
    end
    
    # Test data
    test_data = {
      items: [
        { price: 100.0, quantity: 2 },
        { price: 50.0, quantity: 3 }
      ],
      tax_rate: 0.1
    }
    
    # Get the original result
    original_result = schema_class.from(test_data)
    original_final_total = original_result[:final_total]
    
    # Find all checkpoint files that were created
    checkpoint_files = Dir.glob("#{temp_dir}/*_after.msh").sort
    expect(checkpoint_files.size).to be > 5  # Should have multiple pass checkpoints
    
    # Test resuming from each checkpoint
    checkpoint_files.each do |checkpoint_file|
      pass_name = File.basename(checkpoint_file).split('_')[1]
      
      # Clear previous ENV and set up for resume
      ENV.keys.select { |k| k.start_with?("KUMI_") }.each { |k| ENV.delete(k) }
      ENV["KUMI_RESUME_FROM"] = checkpoint_file
      
      resumed_schema_class = Module.new do
        extend Kumi::Schema
        
        schema do
          input do
            array :items do
              float :price
              integer :quantity
            end
            float :tax_rate
          end
          
          value :subtotals, input.items.price * input.items.quantity
          value :total_before_tax, fn(:sum, ref(:subtotals))
          value :tax_amount, ref(:total_before_tax) * input.tax_rate
          value :final_total, ref(:total_before_tax) + ref(:tax_amount)
        end
      end
      
      resumed_result = resumed_schema_class.from(test_data)
      resumed_final_total = resumed_result[:final_total]
      
      expect(resumed_final_total).to eq(original_final_total), 
        "Result differs when resuming from #{pass_name} checkpoint: #{resumed_final_total} != #{original_final_total}"
    end
  end
end