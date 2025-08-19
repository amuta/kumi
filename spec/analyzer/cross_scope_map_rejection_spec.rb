# frozen_string_literal: true
require "spec_helper"
require_relative "../support/analyzer_state_helper"

RSpec.describe "Cross-scope MAP rejection (Step 1)", :prelower do
  include AnalyzerStateHelper

  it "rejects cross-scope MAP that would require product join (pre-lower)" do
    schema_bad = proc do
      input do
        array :a do 
          integer :x 
        end
        array :b do 
          integer :y 
        end
      end
      # elementwise map across unrelated axes would require product join (not supported)
      value :bad, fn(:add, input.a.x, input.b.y)
    end

    expect {
      analyze_until_join_reduce(schema_bad, { a: [{x:1}], b: [{y:2}] })
    }.to raise_error(Kumi::Core::Errors::AnalysisError, /product|cross-scope map|join policy/i)
  end
end