# frozen_string_literal: true

require "benchmark"
require "benchmark/ips"

return unless ENV["KUMI_PERFORMANCE_TEST"]

# This could be better, we are testing against a simplistic schema
# TODO: improve schema generation to cover more complex/realistic scenario
RSpec.describe "big schema stress test" do
  let!(:big_schema_def) { generate_schema(num_traits: 500, num_vals: 500, cascade_size: 4) }
  let!(:analyzer)      { Kumi::Core::Analyzer.analyze!(big_schema_def) }
  let!(:compiled)      { Kumi::Core::Compiler.compile(big_schema_def, analyzer: analyzer) }

  it "compiles in reasonable time" do
    compilation_time = Benchmark.measure do
      Kumi::Core::Compiler.compile(big_schema_def, analyzer: analyzer)
    end

    expect(compilation_time.real).to be < 0.01
  end

  it "evaluates one trait quickly" do
    data = Hash.new(0).merge(age: 50, balance: 2000, purchases: 10)

    evaluation_time = Benchmark.realtime do
      compiled.evaluate(data)
    end

    expect(evaluation_time).to be < 0.01 # Should evaluate very quickly
  end
end
