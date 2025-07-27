# Wide Schema Compilation and Evaluation Benchmark
#
# This benchmark measures Kumi's performance with increasingly wide schemas
# to understand how compilation and evaluation times scale with schema complexity.
#
# What it tests:
# - Compilation time for schemas with 1k, 5k, and 10k value declarations  
# - Evaluation performance for computing aggregated results from many values
# - Memory efficiency through memoized schema compilation
#
# Schema structure:
# - input: single integer seed
# - values: v1 = seed + 1, v2 = seed + 2, ..., v_n = seed + n  
# - aggregations: sum_all, avg_all
# - trait: large_total (conditional logic)
# - cascade: final_total (depends on trait evaluation)
#
# Usage: bundle exec ruby examples/wide_schema_compilation_and_evaluation_benchmark.rb
require "benchmark"
require "benchmark/ips"
require_relative "../lib/kumi"

# ------------------------------------------------------------------
# 1. Helper that builds a *sugar‑free* wide‑but‑shallow schema
# ------------------------------------------------------------------
def build_wide_schema(width)
  Class.new do
    extend Kumi::Schema

    schema do
      input { integer :seed }

      # width independent leaf nodes: v_i = seed + i
      1.upto(width) { |i| value :"v#{i}", fn(:add, input.seed, i) }

      # Aggregations
      value :sum_all, fn(:sum, (1..width).map { |i| ref(:"v#{i}") })
      value :avg_all, fn(:divide, ref(:sum_all), width)

      trait :large_total,
            ref(:sum_all), :>, (width * (width + 1) / 2)

      value :final_total do
        on large_total, fn(:add, ref(:sum_all), ref(:avg_all))
        base ref(:sum_all)
      end
    end
  end
end

WIDTHS = [1_000, 5_000, 10_000]

# ------------------------------------------------------------------
# 2. Measure compilation once per width
# ------------------------------------------------------------------
compile_times = {}
schemas       = {}

WIDTHS.each do |w|
  t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  schemas[w] = build_wide_schema(w)
  compile_times[w] = Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0
end

puts "=== compilation times ==="
compile_times.each do |w, t|
  puts format("compile %5d‑wide: %6.1f ms", w, t * 1_000)
end
puts

# ------------------------------------------------------------------
# 3. Pure evaluation benchmark – no compilation inside the loop
# ------------------------------------------------------------------
Benchmark.ips do |x|
  schemas.each do |w, schema|
    runner = schema.from(seed: 0)          # memoised runner
    x.report("eval #{w}-wide") { runner[:final_total] }
  end
  x.compare!
end
