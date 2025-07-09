require "benchmark"
require "benchmark/ips"

# This could be better, we are testing against a simplistic schema
# TODO: improve schema generation to cover more complex/realistic scenario
RSpec.describe "big schema stress test" do
  let!(:big_schema_def) { generate_complex_schema }
  let!(:analyzer)      { Kumi::Analyzer.analyze!(big_schema_def) }
  let!(:compiled)      { Kumi::Compiler.compile(big_schema_def, analyzer: analyzer) }

  it "compiles in reasonable time" do
    compilation_time = Benchmark.measure do
      Kumi::Compiler.compile(big_schema_def, analyzer: analyzer)
    end

    expect(compilation_time.real).to be < 3
  end

  it "evaluates one predicate quickly" do
    data = Hash.new(0).merge(age: 50, balance: 2000, purchases: 10)
    Benchmark.ips do |x|
      x.report("5k predi/values, 1 value that depends on all") do
        compiled.evaluate(data)
      end
    end
  end
end
