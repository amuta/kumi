# frozen_string_literal: true

require "json"
require "fileutils"
require "time"

module Kumi
  module Core
    module IR
      module ExecutionEngine
        module Profiler
          class << self
            def enabled? = ENV["KUMI_PROFILE"] == "1"

            def reset!(meta: {})
              return unless enabled?
              @events = []
              @meta   = meta
              @file   = ENV["KUMI_PROFILE_FILE"] || "tmp/profile.jsonl"
              @run_id = (@run_id || 0) + 1  # Track run number for averaging
              @aggregated_stats = (@aggregated_stats || Hash.new { |h, k| h[k] = { count: 0, total_ms: 0.0, total_cpu_ms: 0.0, rows: 0, runs: Set.new } })
              
              if ENV["KUMI_PROFILE_TRUNCATE"] == "1"
                FileUtils.mkdir_p(File.dirname(@file))
                File.write(@file, "")
                @aggregated_stats.clear  # Clear aggregated stats on truncate
              end
            end

            # monotonic start time
            def t0
              Process.clock_gettime(Process::CLOCK_MONOTONIC)
            end
            
            # CPU time start (process + thread)
            def cpu_t0
              Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID)
            end

            # Per-op record with both wall time and CPU time
            def record!(decl:, idx:, tag:, op:, t0:, cpu_t0: nil, rows: nil, note: nil)
              return unless enabled?
              
              wall_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0) * 1000.0)
              cpu_ms = cpu_t0 ? ((Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID) - cpu_t0) * 1000.0) : wall_ms
              
              ev = {
                ts:     Time.now.utc.iso8601(3),
                run:    @run_id,
                decl:   decl,     # decl name (string/symbol)
                i:      idx,      # op index
                tag:    tag,      # op tag (symbol)
                wall_ms: wall_ms.round(4),
                cpu_ms:  cpu_ms.round(4),
                rows:   rows,
                note:   note,
                key:    op_key(decl, idx, tag, op),      # stable key for grep/diff
                attrs:  compact_attrs(op.attrs)
              }
              
              # Aggregate stats for multi-run averaging
              op_key = "#{decl}@#{idx}:#{tag}"
              agg = @aggregated_stats[op_key]
              agg[:count] += 1
              agg[:total_ms] += wall_ms
              agg[:total_cpu_ms] += cpu_ms
              agg[:rows] += (rows || 0)
              agg[:runs] << @run_id
              agg[:decl] = decl
              agg[:tag] = tag
              agg[:idx] = idx
              agg[:note] = note if note
              
              (@events ||= []) << ev
              stream(ev) if ENV["KUMI_PROFILE_STREAM"] == "1"
              ev
            end

            def summary(top: 20)
              return {} unless enabled?
              
              # Current run summary (legacy format)
              current_agg = Hash.new { |h, k| h[k] = { count: 0, ms: 0.0, rows: 0 } }
              (@events || []).each do |e|
                k = [e[:decl], e[:tag]]
                a = current_agg[k]
                a[:count] += 1
                a[:ms]    += (e[:wall_ms] || e[:ms] || 0)
                a[:rows]  += (e[:rows] || 0)
              end
              current_ranked = current_agg.map { |(decl, tag), v|
                { decl: decl, tag: tag, count: v[:count], ms: v[:ms].round(3), rows: v[:rows],
                  rps: v[:rows] > 0 ? (v[:rows] / v[:ms]).round(1) : nil }
              }.sort_by { |h| -h[:ms] }.first(top)

              { meta: @meta || {}, top: current_ranked,
                total_ms: ((@events || []).sum { |e| e[:wall_ms] || e[:ms] || 0 }).round(3),
                op_count: (@events || []).size,
                run_id: @run_id }
            end
            
            # Multi-run averaged analysis
            def averaged_analysis(top: 20)
              return {} unless enabled? && @aggregated_stats&.any?
              
              # Convert aggregated stats to averaged metrics
              averaged = @aggregated_stats.map do |op_key, stats|
                num_runs = stats[:runs].size
                avg_wall_ms = stats[:total_ms] / stats[:count]
                avg_cpu_ms = stats[:total_cpu_ms] / stats[:count] 
                total_wall_ms = stats[:total_ms]
                total_cpu_ms = stats[:total_cpu_ms]
                
                {
                  op_key: op_key,
                  decl: stats[:decl],
                  idx: stats[:idx], 
                  tag: stats[:tag],
                  runs: num_runs,
                  total_calls: stats[:count],
                  calls_per_run: stats[:count] / num_runs.to_f,
                  avg_wall_ms: avg_wall_ms.round(4),
                  avg_cpu_ms: avg_cpu_ms.round(4),
                  total_wall_ms: total_wall_ms.round(3),
                  total_cpu_ms: total_cpu_ms.round(3),
                  cpu_efficiency: total_wall_ms > 0 ? (total_cpu_ms / total_wall_ms * 100).round(1) : 100,
                  rows_total: stats[:rows],
                  note: stats[:note]
                }
              end.sort_by { |s| -s[:total_wall_ms] }.first(top)
              
              {
                meta: @meta || {},
                total_runs: (@aggregated_stats.values.map { |s| s[:runs].size }.max || 0),
                averaged_ops: averaged,
                total_operations: @aggregated_stats.size
              }
            end
            
            # Identify potential cache overhead operations
            def cache_overhead_analysis
              return {} unless enabled? && @aggregated_stats&.any?
              
              # Look for operations that might be cache-related
              cache_ops = @aggregated_stats.select do |op_key, stats|
                op_key.include?("ref") || op_key.include?("load_input") || stats[:note]&.include?("cache")
              end
              
              cache_analysis = cache_ops.map do |op_key, stats|
                num_runs = stats[:runs].size
                avg_wall_ms = stats[:total_ms] / stats[:count]
                
                {
                  op_key: op_key,
                  decl: stats[:decl],
                  tag: stats[:tag],
                  avg_time_ms: avg_wall_ms.round(4),
                  total_time_ms: stats[:total_ms].round(3),
                  call_count: stats[:count],
                  overhead_per_call: avg_wall_ms.round(6)
                }
              end.sort_by { |s| -s[:total_time_ms] }
              
              {
                cache_operations: cache_analysis,
                total_cache_time: cache_analysis.sum { |op| op[:total_time_ms] }.round(3)
              }
            end

            def emit_summary!
              return unless enabled?
              stream({ ts: Time.now.utc.iso8601(3), kind: "summary", data: summary })
            end

            # Stable textual key for "match ops one by one"
            def op_key(decl, idx, tag, op)
              attrs = compact_attrs(op.attrs)
              args  = op.args
              "#{decl}@#{idx}:#{tag}|#{attrs.keys.sort_by(&:to_s).map { |k| "#{k}=#{attrs[k].inspect}" }.join(",")}|args=#{args.inspect}"
            end

            def compact_attrs(h)
              return {} unless h
              h.transform_values do |v|
                case v
                when Array, Hash, Symbol, String, Numeric, TrueClass, FalseClass, NilClass then v
                else v.to_s
                end
              end
            end

            def stream(obj)
              return unless @file
              FileUtils.mkdir_p(File.dirname(@file))
              File.open(@file, "a") { |f| f.puts(obj.to_json) }
            end
          end
        end
      end
    end
  end
end