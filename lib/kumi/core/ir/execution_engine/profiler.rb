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
              if ENV["KUMI_PROFILE_TRUNCATE"] == "1"
                FileUtils.mkdir_p(File.dirname(@file))
                File.write(@file, "")
              end
            end

            # monotonic start time
            def t0
              Process.clock_gettime(Process::CLOCK_MONOTONIC)
            end

            # Per-op record
            def record!(decl:, idx:, tag:, op:, t0:, rows: nil, note: nil)
              return unless enabled?
              ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0) * 1000.0)
              ev = {
                ts:  Time.now.utc.iso8601(3),
                decl: decl,     # decl name (string/symbol)
                i:    idx,      # op index
                tag:  tag,      # op tag (symbol)
                ms:   ms.round(3),
                rows: rows,
                note: note,
                key:  op_key(decl, idx, tag, op),      # stable key for grep/diff
                attrs: compact_attrs(op.attrs)
              }
              (@events ||= []) << ev
              stream(ev) if ENV["KUMI_PROFILE_STREAM"] == "1"
              ev
            end

            def summary(top: 20)
              return {} unless enabled?
              agg = Hash.new { |h, k| h[k] = { count: 0, ms: 0.0, rows: 0 } }
              (@events || []).each do |e|
                k = [e[:decl], e[:tag]]
                a = agg[k]
                a[:count] += 1
                a[:ms]    += e[:ms]
                a[:rows]  += (e[:rows] || 0)
              end
              ranked = agg.map { |(decl, tag), v|
                { decl: decl, tag: tag, count: v[:count], ms: v[:ms].round(3), rows: v[:rows],
                  rps: v[:rows] > 0 ? (v[:rows] / v[:ms]).round(1) : nil }
              }.sort_by { |h| -h[:ms] }.first(top)

              { meta: @meta || {}, top: ranked,
                total_ms: ((@events || []).sum { _1[:ms] }).round(3),
                op_count: (@events || []).size }
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