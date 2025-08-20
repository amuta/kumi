# frozen_string_literal: true

require "json"
require "set"

module Kumi
  module Core
    module Analyzer
      module StateSerde
        module_function

        # Exact round-trip (recommended for resume)
        def dump_marshal(state)
          Marshal.dump({ v: 1, data: state.to_h })
        end

        def load_marshal(bytes)
          payload = Marshal.load(bytes)
          ::Kumi::Core::Analyzer::AnalysisState.new(payload[:data])
        end

        # Human-readable snapshot (best-effort; not guaranteed resumable)
        def dump_json(state, pretty: true)
          h = encode_json_safe(state.to_h)
          pretty ? JSON.pretty_generate(h) : JSON.generate(h)
        end

        def load_json(json_str)
          h = JSON.parse(json_str, symbolize_names: true)
          ::Kumi::Core::Analyzer::AnalysisState.new(decode_json_safe(h))
        end

        # ---- helpers ----
        def encode_json_safe(x)
          case x
          when Hash  then x.transform_keys(&:to_s).transform_values { |v| encode_json_safe(v) }
          when Array then x.map { |v| encode_json_safe(v) }
          when Set   then { "$set" => x.to_a.map { |v| encode_json_safe(v) } }
          when Symbol then { "$sym" => x.to_s }
          when ::Kumi::Core::IR::Module, ::Kumi::Core::IR::Decl, ::Kumi::Core::IR::Op
            { "$ir" => x.inspect }
          else x
          end
        end

        def decode_json_safe(x)
          case x
          when Hash
            if    x.key?("$sym") then x["$sym"].to_sym
            elsif x.key?("$set") then Set.new(x["$set"].map { decode_json_safe(_1) })
            elsif x.key?("$ir")  then x["$ir"]  # Keep as string inspection for JSON round-trip
            else x.transform_keys(&:to_sym).transform_values { decode_json_safe(_1) }
            end
          when Array then x.map { decode_json_safe(_1) }
          else x
          end
        end
      end
    end
  end
end