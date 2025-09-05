# frozen_string_literal: true

require "spec_helper"

RSpec.describe "RubyV3 Integration: Reductions and Aggregations" do
  include PackTestHelper

  it "handles sum reductions with accumulator logic" do
    schema = <<~KUMI
      schema do
        input do
          array :items do
            integer :quantity
          end
        end
        
        value :total_qty, fn(:sum, input.items.quantity)
      end
    KUMI
    
    pack = pack_for(schema)
    generator = Kumi::Codegen::RubyV3::Generator.new(pack, module_name: "Aggregator")
    
    result = generator.render
    
    # Should generate reduction logic with accumulators
    expect(result).to include("acc_")           # Accumulator variables
    expect(result).to include("agg.sum")        # Sum kernel dispatch
    expect(result).to include("_each_total_qty") # Streaming method
    expect(result).to include("_eval_total_qty") # Materialization method
    
    # Since it's a rank-0 result, should use direct return
    expect(result).to include("{ |value, _| return value }")
  end
end