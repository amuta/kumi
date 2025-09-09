# frozen_string_literal: true

require "json"
require "fileutils"
require "benchmark"

module Kumi
  module Dev
    module ProfileRunner
      module_function

      def run(script_path, opts = {})
        # Validate script exists
        unless File.exist?(script_path)
          puts "Error: Script not found: #{script_path}"
          return false
        end

        # Set up profiling environment
        setup_profiler_env(opts)

        puts "Profiling: #{script_path}"
        puts "Configuration:"
        puts "  Output: #{ENV.fetch('KUMI_PROFILE_FILE', nil)}"
        puts "  Phases: enabled"
        puts "  Operations: #{ENV['KUMI_PROFILE_OPS'] == '1' ? 'enabled' : 'disabled'}"
        puts "  Sampling: #{ENV['KUMI_PROFILE_SAMPLE'] || '1'}"
        puts "  Persistent: #{ENV['KUMI_PROFILE_PERSISTENT'] == '1' ? 'yes' : 'no'}"
        puts "  Memory snapshots: #{opts[:memory] ? 'enabled' : 'disabled'}"
        puts

        # Initialize profiler
        Dev::Profiler.init_persistent! if ENV["KUMI_PROFILE_PERSISTENT"] == "1"

        # Add memory snapshot before execution
        Dev::Profiler.memory_snapshot("script_start") if opts[:memory]

        # Execute the script
        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        begin
          Dev::Profiler.phase("script_execution", script: File.basename(script_path)) do
            # Execute in a clean environment to avoid polluting the current process
            load(File.expand_path(script_path))
          end
        rescue StandardError => e
          puts "Error executing script: #{e.message}"
          puts e.backtrace.first(5).join("\n")
          return false
        ensure
          execution_time = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
        end

        # Add memory snapshot after execution
        Dev::Profiler.memory_snapshot("script_end") if opts[:memory]

        # Finalize profiler to get aggregated data
        Dev::Profiler.finalize!

        puts "Script completed in #{execution_time.round(4)}s"

        # Show analysis unless quiet
        show_analysis(opts) unless opts[:quiet]

        true
      rescue LoadError => e
        puts "Error loading script: #{e.message}"
        false
      end

      def self.setup_profiler_env(opts)
        # Always enable profiling
        ENV["KUMI_PROFILE"] = "1"

        # Output file
        output_file = opts[:output] || "tmp/profile.jsonl"
        ENV["KUMI_PROFILE_FILE"] = output_file

        # Truncate if requested
        ENV["KUMI_PROFILE_TRUNCATE"] = opts[:truncate] ? "1" : "0"

        # Streaming
        ENV["KUMI_PROFILE_STREAM"] = opts[:stream] ? "1" : "0"

        # Operations profiling
        ENV["KUMI_PROFILE_OPS"] = if opts[:phases_only]
                                    "0"
                                  elsif opts[:ops]
                                    "1"
                                  else
                                    # Default: phases only
                                    "0"
                                  end

        # Sampling
        ENV["KUMI_PROFILE_SAMPLE"] = opts[:sample].to_s if opts[:sample]

        # Persistent mode
        ENV["KUMI_PROFILE_PERSISTENT"] = opts[:persistent] ? "1" : "0"

        # Ensure output directory exists
        FileUtils.mkdir_p(File.dirname(output_file))
      end

      def self.show_analysis(opts)
        output_file = ENV.fetch("KUMI_PROFILE_FILE", nil)

        unless File.exist?(output_file)
          puts "No profile data generated"
          return
        end

        puts "\n=== Profiling Analysis ==="

        # Use ProfileAggregator for comprehensive analysis
        require_relative "profile_aggregator"
        aggregator = ProfileAggregator.new(output_file)

        if opts[:json]
          # Export full analysis to JSON and display
          json_output = opts[:json_file] || "/tmp/profile_analysis.json"
          aggregator.export_summary(json_output)
          puts File.read(json_output)
          return
        end

        # Show comprehensive analysis using ProfileAggregator
        if opts[:detailed]
          aggregator.detailed_report(limit: opts[:limit] || 15)
        else
          # Show summary + key insights
          aggregator.summary_report

          # Add some key insights for CLI users
          puts
          puts "=== KEY INSIGHTS ==="

          # Show top hotspots
          hotspots = aggregator.hotspot_analysis(limit: 3)
          if hotspots.any?
            puts "Top Performance Bottlenecks:"
            hotspots.each_with_index do |(_key, stats), i|
              puts "  #{i + 1}. #{stats[:decl]} (#{stats[:tag]}): #{stats[:total_ms]}ms"
            end
          end

          # Reference analysis summary
          ref_analysis = aggregator.reference_operation_analysis
          if ref_analysis[:operations] > 0
            puts "Reference Operation Impact: #{(ref_analysis[:total_time] / aggregator.vm_execution_time * 100).round(1)}% of VM time"
          end

          # Memory impact
          mem = aggregator.memory_analysis
          puts "Memory Impact: #{mem[:growth][:heap_growth_pct]}% heap growth, #{mem[:growth][:rss_growth_pct]}% RSS growth" if mem
        end

        puts
        puts "Full profile: #{output_file}"
        puts "For detailed analysis: bin/kumi profile #{ARGV.join(' ')} --detailed"
      end

      def self.analyze_phases(phase_events)
        phase_events.group_by { |e| e["name"] }.transform_values do |events|
          {
            count: events.length,
            total_ms: events.sum { |e| e["wall_ms"] }.round(3),
            avg_ms: (events.sum { |e| e["wall_ms"] } / events.length).round(4)
          }
        end.sort_by { |_, stats| -stats[:total_ms] }.to_h
      end

      def self.analyze_events(events)
        {
          summary: {
            total_events: events.length,
            phase_events: events.count { |e| e["kind"] == "phase" },
            memory_events: events.count { |e| e["kind"] == "mem" },
            operation_events: events.count { |e| !%w[phase mem summary final_summary cache_analysis].include?(e["kind"]) }
          },
          phases: analyze_phases(events.select { |e| e["kind"] == "phase" }),
          memory_snapshots: events.select { |e| e["kind"] == "mem" }.map do |e|
            {
              label: e["label"],
              heap_live: e["heap_live"],
              rss_mb: e["rss_mb"],
              timestamp: e["ts"]
            }
          end,
          final_analysis: events.find { |e| e["kind"] == "final_summary" }&.dig("data"),
          cache_analysis: events.find { |e| e["kind"] == "cache_analysis" }&.dig("data")
        }
      end
    end
  end
end
