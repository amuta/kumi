# Deep Schema Compilation and Evaluation Benchmark
#
# This benchmark measures Kumi's performance with increasingly deep dependency chains
# to understand how compilation and evaluation times scale with schema depth.
#
# What it tests:
# - Compilation time for schemas with deep dependency chains (50, 100, 150 levels)
# - Evaluation performance for computing results through long dependency paths
# - Stack-safe evaluation through iterative dependency resolution
#
# Schema structure:
# - input: single integer seed
# - values: chain of dependencies v0 = seed, v1 = v0 + 1, v2 = v1 + 2, ..., v_n = v_(n-1) + n
# - traits: conditional checks at each level (value > threshold)
# - cascade: final_result depends on first trait that evaluates to true
#
# Depth limits: Ruby stack overflow occurs around 200-300 levels depending on system,
# so we test with conservative depths (50, 100, 150) to ensure reliability.
#
# Usage: bundle exec ruby examples/deep_schema_compilation_and_evaluation_benchmark.rb
require "benchmark"
require "benchmark/ips"
require_relative "../lib/kumi"

# ------------------------------------------------------------------
# 1. Helper that builds a deep dependency chain schema
# ------------------------------------------------------------------
def build_deep_schema(depth)
  Class.new do
    extend Kumi::Schema

    schema do
      input { integer :seed }

      # Build dependency chain: v0 = seed, v1 = v0 + 1, v2 = v1 + 2, etc.
      value :v0, input.seed
      
      (1...depth).each do |i|
        value :"v#{i}", fn(:add, ref(:"v#{i-1}"), i)
      end

      # Build traits that check if values exceed thresholds
      # Use varying thresholds to create realistic evaluation scenarios
      (0...depth).each do |i|
        threshold = i * (i + 1) / 2 + 1000  # Quadratic growth to ensure variety
        trait :"threshold_#{i}", fn(:>, ref(:"v#{i}"), threshold)
      end

      # Final cascade that finds first trait that's true
      value :final_result do
        (0...depth).each do |i|
          on :"threshold_#{i}", fn(:multiply, ref(:"v#{i}"), 2)
        end
        base ref(:"v#{depth-1}")  # Default to final value
      end
    end
  end
end

# Conservative depths to avoid Ruby stack overflow
# Ruby stack depth limit is around 1000-2000 frames depending on the system
# Keep depths well below this limit for reliable operation
DEPTHS = [50, 100, 150, 200]

# ------------------------------------------------------------------
# 2. Measure compilation once per depth
# ------------------------------------------------------------------
compile_times = {}
schemas       = {}

DEPTHS.each do |d|
  t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  schemas[d] = build_deep_schema(d)
  compile_times[d] = Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0
end

puts "=== compilation times ==="
compile_times.each do |d, t|
  puts format("compile %3d-deep: %6.1f ms", d, t * 1_000)
end
puts

# ------------------------------------------------------------------
# 3. Pure evaluation benchmark – no compilation inside the loop
# ------------------------------------------------------------------
Benchmark.ips do |x|
  schemas.each do |d, schema|
    runner = schema.from(seed: 0)          # memoised runner
    x.report("eval #{d}-deep") { runner[:final_result] }
  end
  x.compare!
end
# Warming up --------------------------------------
#         eval 50-deep   222.000 i/100ms
#        eval 100-deep    57.000 i/100ms
#        eval 150-deep    26.000 i/100ms
# Calculating -------------------------------------
#         eval 50-deep      2.166k (± 1.9%) i/s  (461.70 μs/i) -     10.878k in   5.024320s
#        eval 100-deep    561.698 (± 1.4%) i/s    (1.78 ms/i) -      2.850k in   5.075057s
#        eval 150-deep    253.732 (± 0.8%) i/s    (3.94 ms/i) -      1.274k in   5.021499s

# Comparison:
#         eval 50-deep:     2165.9 i/s
#        eval 100-deep:      561.7 i/s - 3.86x  slower
#        eval 150-deep:      253.7 i/s - 8.54x  slower