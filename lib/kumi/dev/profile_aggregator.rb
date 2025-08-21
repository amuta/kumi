# frozen_string_literal: true

require 'json'

module Kumi
  module Dev
    class ProfileAggregator
      attr_reader :events, :phases, :operations, :memory_snapshots, :final_summary

      def initialize(jsonl_file)
        @jsonl_file = jsonl_file
        @events = []
        @phases = []
        @operations = []
        @memory_snapshots = []
        @final_summary = nil
        load_events
      end

      def self.load(jsonl_file)
        new(jsonl_file)
      end

      # Core aggregation methods
      def total_execution_time
        script_phase = phases.find { |p| p["name"] == "script_execution" }
        script_phase ? script_phase["wall_ms"] : 0
      end

      def vm_execution_time
        vm_phases = phases.select { |p| p["name"] == "vm.run" }
        vm_phases.sum { |p| p["wall_ms"] || 0 }
      end

      def vm_execution_count
        phases.count { |p| p["name"] == "vm.run" }
      end

      def runs_analyzed
        (operations + phases + memory_snapshots).map { |e| e["run"] }.compact.uniq.sort
      end

      def schema_breakdown
        @schema_breakdown ||= operations.group_by { |op| op["schema"] || "Unknown" }.transform_values do |ops|
          {
            operations: ops.length,
            time: ops.sum { |op| op["wall_ms"] || 0 }.round(4),
            declarations: ops.map { |op| op["decl"] }.uniq.compact.sort
          }
        end
      end

      def operations_by_run
        operations.group_by { |op| op["run"] }
      end

      def operation_stats_by_type
        operations.group_by { |op| op["tag"] }.transform_values do |ops|
          {
            count: ops.length,
            total_ms: ops.sum { |op| op["wall_ms"] || 0 }.round(4),
            avg_ms: ops.empty? ? 0 : (ops.sum { |op| op["wall_ms"] || 0 } / ops.length).round(6),
            max_ms: ops.map { |op| op["wall_ms"] || 0 }.max || 0,
            declarations: ops.map { |op| op["decl"] }.uniq.compact
          }
        end.sort_by { |_, stats| -stats[:total_ms] }
      end

      def operation_stats_by_declaration
        operations.group_by { |op| op["decl"] }.transform_values do |ops|
          {
            count: ops.length,
            total_ms: ops.sum { |op| op["wall_ms"] || 0 }.round(4),
            avg_ms: ops.empty? ? 0 : (ops.sum { |op| op["wall_ms"] || 0 } / ops.length).round(6),
            operation_types: ops.map { |op| op["tag"] }.uniq.compact
          }
        end.sort_by { |_, stats| -stats[:total_ms] }
      end

      def hotspot_analysis(limit: 20)
        operations.map do |op|
          {
            key: "#{op['decl']}@#{op['seq'] || 0}:#{op['tag']}",
            decl: op["decl"],
            tag: op["tag"],
            wall_ms: op["wall_ms"] || 0,
            cpu_ms: op["cpu_ms"] || 0,
            rows: op["rows"] || 0
          }
        end.group_by { |op| op[:key] }.transform_values do |ops|
          {
            count: ops.length,
            total_ms: ops.sum { |op| op[:wall_ms] }.round(4),
            avg_ms: ops.empty? ? 0 : (ops.sum { |op| op[:wall_ms] } / ops.length).round(6),
            decl: ops.first[:decl],
            tag: ops.first[:tag]
          }
        end.sort_by { |_, stats| -stats[:total_ms] }.first(limit)
      end

      def reference_operation_analysis
        ref_ops = operations.select { |op| op["tag"] == "ref" }
        return { operations: 0, total_time: 0, avg_time: 0, by_declaration: [] } if ref_ops.empty?

        {
          operations: ref_ops.length,
          total_time: ref_ops.sum { |op| op["wall_ms"] || 0 }.round(4),
          avg_time: (ref_ops.sum { |op| op["wall_ms"] || 0 } / ref_ops.length).round(6),
          by_declaration: ref_ops.group_by { |op| op["decl"] }.transform_values do |ops|
            {
              count: ops.length,
              total_ms: ops.sum { |op| op["wall_ms"] || 0 }.round(4),
              avg_ms: (ops.sum { |op| op["wall_ms"] || 0 } / ops.length).round(6)
            }
          end.sort_by { |_, stats| -stats[:total_ms] }
        }
      end

      def memory_analysis
        return nil if memory_snapshots.length < 2

        start_mem = memory_snapshots.first
        end_mem = memory_snapshots.last

        {
          start: {
            heap_live: start_mem["heap_live"],
            rss_mb: start_mem["rss_mb"],
            minor_gc: start_mem["minor_gc"],
            major_gc: start_mem["major_gc"]
          },
          end: {
            heap_live: end_mem["heap_live"],
            rss_mb: end_mem["rss_mb"],
            minor_gc: end_mem["minor_gc"],
            major_gc: end_mem["major_gc"]
          },
          growth: {
            heap_objects: end_mem["heap_live"] - start_mem["heap_live"],
            heap_growth_pct: ((end_mem["heap_live"] - start_mem["heap_live"]).to_f / start_mem["heap_live"] * 100).round(1),
            rss_mb: (end_mem["rss_mb"] - start_mem["rss_mb"]).round(2),
            rss_growth_pct: ((end_mem["rss_mb"] - start_mem["rss_mb"]) / start_mem["rss_mb"] * 100).round(1),
            minor_gcs: end_mem["minor_gc"] - start_mem["minor_gc"],
            major_gcs: end_mem["major_gc"] - start_mem["major_gc"]
          }
        }
      end

      def phase_analysis
        phases.group_by { |p| p["name"] }.transform_values do |phase_events|
          {
            count: phase_events.length,
            total_ms: phase_events.sum { |p| p["wall_ms"] || 0 }.round(4),
            avg_ms: phase_events.empty? ? 0 : (phase_events.sum { |p| p["wall_ms"] || 0 } / phase_events.length).round(4),
            max_ms: phase_events.map { |p| p["wall_ms"] || 0 }.max || 0
          }
        end.sort_by { |_, stats| -stats[:total_ms] }
      end

      # Reporting methods
      def summary_report
        total_ops = operations.length
        total_vm_time = vm_execution_time
        ref_analysis = reference_operation_analysis

        puts "=== PROFILE AGGREGATION SUMMARY ==="
        puts "Total events: #{events.length}"
        puts "VM operations: #{total_ops}"
        puts "VM executions: #{vm_execution_count}"
        
        # Schema differentiation
        schema_stats = schema_breakdown
        if schema_stats.any? && schema_stats.keys.first != "Unknown"
          puts "Schemas analyzed: #{schema_stats.keys.join(", ")}"
          schema_stats.each do |schema, stats|
            puts "  #{schema}: #{stats[:operations]} operations, #{stats[:time]}ms"
          end
        else
          puts "Schema runs: #{runs_analyzed.length} (runs: #{runs_analyzed.join(', ')})"
        end
        
        puts "Total VM time: #{total_vm_time.round(4)}ms"
        puts "Average per VM execution: #{vm_execution_count > 0 ? (total_vm_time / vm_execution_count).round(4) : 0}ms"
        puts

        if ref_analysis[:operations] && ref_analysis[:operations] > 0
          puts "Reference Operations:"
          puts "  Count: #{ref_analysis[:operations]} (#{(ref_analysis[:operations].to_f / total_ops * 100).round(1)}% of all ops)"
          puts "  Time: #{ref_analysis[:total_time]}ms (#{total_vm_time > 0 ? (ref_analysis[:total_time] / total_vm_time * 100).round(1) : 0}% of VM time)"
          puts "  Avg: #{ref_analysis[:avg_time]}ms per reference"
        end

        mem = memory_analysis
        if mem
          puts
          puts "Memory Growth:"
          puts "  Heap: +#{mem[:growth][:heap_objects]} objects (#{mem[:growth][:heap_growth_pct]}%)"
          puts "  RSS: +#{mem[:growth][:rss_mb]}MB (#{mem[:growth][:rss_growth_pct]}%)"
          puts "  GC: #{mem[:growth][:minor_gcs]} minor, #{mem[:growth][:major_gcs]} major"
        end
      end

      def detailed_report(limit: 15)
        summary_report
        puts
        puts "=== TOP #{limit} HOTSPOTS ==="
        hotspots = hotspot_analysis(limit: limit)
        hotspots.each_with_index do |(key, stats), i|
          puts "#{(i+1).to_s.rjust(2)}. #{key.ljust(40)} #{stats[:total_ms].to_s.rjust(10)}ms (#{stats[:count]} calls, #{stats[:avg_ms]}ms avg)"
        end

        # Schema breakdown if available
        schema_stats = schema_breakdown
        if schema_stats.keys.length > 1 || (schema_stats.keys.first && schema_stats.keys.first != "Unknown")
          puts
          puts "=== SCHEMA BREAKDOWN ==="
          schema_stats.each do |schema, stats|
            puts "#{schema}:"
            puts "  Operations: #{stats[:operations]}"
            puts "  Total time: #{stats[:time]}ms"
            puts "  Declarations: #{stats[:declarations].join(", ")}"
            puts
          end
        end

        puts "=== OPERATION TYPE BREAKDOWN ==="
        operation_stats_by_type.each do |op_type, stats|
          puts "#{op_type.ljust(15)} #{stats[:count].to_s.rjust(8)} calls  #{stats[:total_ms].to_s.rjust(12)}ms  #{stats[:avg_ms].to_s.rjust(10)}ms avg"
        end

        puts
        puts "=== TOP #{limit} DECLARATIONS BY TIME ==="
        operation_stats_by_declaration.first(limit).each do |decl, stats|
          puts "#{decl.to_s.ljust(35)} #{stats[:count].to_s.rjust(6)} ops  #{stats[:total_ms].to_s.rjust(10)}ms"
        end
      end

      def export_summary(filename)
        summary = {
          metadata: {
            total_events: events.length,
            vm_operations: operations.length,
            vm_executions: vm_execution_count,
            analysis_timestamp: Time.now.strftime("%Y-%m-%dT%H:%M:%SZ")
          },
          timing: {
            total_execution_ms: total_execution_time,
            vm_execution_ms: vm_execution_time,
            avg_vm_execution_ms: vm_execution_count > 0 ? (vm_execution_time / vm_execution_count).round(4) : 0
          },
          operations: {
            by_type: operation_stats_by_type,
            by_declaration: operation_stats_by_declaration,
            hotspots: hotspot_analysis(limit: 20)
          },
          references: reference_operation_analysis,
          memory: memory_analysis,
          phases: phase_analysis
        }

        File.write(filename, JSON.pretty_generate(summary))
        puts "Summary exported to: #{filename}"
      end

      private

      def load_events
        return unless File.exist?(@jsonl_file)

        File.readlines(@jsonl_file).each do |line|
          begin
            event = JSON.parse(line.strip)
            next unless event && event.is_a?(Hash)

            @events << event

            case event["kind"]
            when "phase"
              @phases << event
            when "mem"
              @memory_snapshots << event
            when "final_summary"
              @final_summary = event
            else
              # VM operations don't have a "kind" field - they have ts, run, decl, i, tag, wall_ms, cpu_ms, etc.
              # According to profiler.rb line 118-130, VM operations are identified by having decl + tag but no kind
              if event["decl"] && event["tag"] && !event["kind"]
                @operations << event
              elsif event["kind"] && !["summary", "cache_analysis"].include?(event["kind"])
                # Handle any future event types that have a kind but aren't known
                @operations << event
              end
            end
          rescue JSON::ParserError
            # Skip malformed JSON lines
          end
        end
      end
    end
  end
end