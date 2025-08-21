# frozen_string_literal: true

require "json"
require "time"

module Kumi
  module Core
    module Analyzer
      module Debug
        KEY = :kumi_debug_log
        
        class << self
          def enabled?
            ENV["KUMI_DEBUG_STATE"] == "1"
          end

          def output_path
            ENV["KUMI_DEBUG_OUTPUT_PATH"]
          end

          def max_depth
            (ENV["KUMI_DEBUG_MAX_DEPTH"] || "5").to_i
          end

          def max_items
            (ENV["KUMI_DEBUG_MAX_ITEMS"] || "100").to_i
          end

          # Log buffer management
          def reset_log(pass:)
            Thread.current[KEY] = { pass: pass, events: [] }
          end

          def drain_log
            stash = Thread.current[KEY]
            Thread.current[KEY] = nil
            (stash && stash[:events]) || []
          end

          def log(level:, id:, method: nil, **fields)
            buf = Thread.current[KEY]
            return unless buf

            loc = caller_locations(1, 1)&.first
            meth = method || loc&.base_label
            buf[:events] << {
              ts: Time.now.utc.iso8601,
              pass: buf[:pass],
              level: level,
              id: id,
              method: meth,
              file: loc&.path,
              line: loc&.lineno,
              **fields
            }
          end

          def info(id, **fields)
            log(level: :info, id: id, **fields)
          end

          def debug(id, **fields)
            log(level: :debug, id: id, **fields)
          end

          def trace(id, **start_fields)
            t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
            info("#{id}_start".to_sym, **start_fields)
            yield.tap do |ret|
              dt = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0) * 1000).round(2)
              info("#{id}_finish".to_sym, ms: dt)
              ret
            end
          rescue => e
            log(level: :error, id: "#{id}_error".to_sym, error: e.class.name, message: e.message)
            raise
          end

          # State diffing
          def diff_state(before, after)
            changes = {}
            
            all_keys = (before.keys + after.keys).uniq
            all_keys.each do |key|
              if !before.key?(key)
                changes[key] = { type: :added, value: truncate(after[key]) }
              elsif !after.key?(key)
                changes[key] = { type: :removed, value: truncate(before[key]) }
              elsif before[key] != after[key]
                changes[key] = {
                  type: :changed,
                  before: truncate(before[key]),
                  after: truncate(after[key])
                }
              end
            end
            
            changes
          end

          # Emit debug event
          def emit(pass:, diff:, elapsed_ms:, logs:)
            payload = {
              ts: Time.now.utc.iso8601,
              pass: pass,
              elapsed_ms: elapsed_ms,
              diff: diff,
              logs: logs
            }
            
            if output_path && !output_path.empty?
              File.open(output_path, "a") { |f| f.puts(JSON.dump(payload)) }
            else
              $stdout.puts "\n=== STATE #{pass} (#{elapsed_ms}ms) ==="
              $stdout.puts JSON.pretty_generate(payload)
            end
          end

          private

          def truncate(value, depth = max_depth)
            return value if depth <= 0
            
            case value
            when Hash
              if value.size > max_items
                truncated = value.first(max_items).to_h
                truncated[:__truncated__] = "... #{value.size - max_items} more"
                truncated.transform_values { |v| truncate(v, depth - 1) }
              else
                value.transform_values { |v| truncate(v, depth - 1) }
              end
            when Array
              if value.size > max_items
                truncated = value.first(max_items).dup
                truncated << "... #{value.size - max_items} more"
                truncated.map { |v| truncate(v, depth - 1) }
              else
                value.map { |v| truncate(v, depth - 1) }
              end
            when String
              value
            else
              value
            end
          end

        end

        # Mixin for passes
        module Loggable
          def log_info(id, **fields)
            Debug.info(id, method: __method__, **fields)
          end

          def log_debug(id, **fields)
            Debug.debug(id, method: __method__, **fields)
          end

          def trace(id, **fields, &block)
            Debug.trace(id, **fields, &block)
          end
        end
      end
    end
  end
end