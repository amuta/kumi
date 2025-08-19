# frozen_string_literal: true

module Kumi
  module Support
    module StateDumper
      module_function

      def dump_state(state, keys: nil, max_depth: 3)
        keys_to_dump = keys || state.keys
        
        keys_to_dump.each do |key|
          value = state[key]
          puts "=== #{key.to_s.upcase} ==="
          dump_value(value, depth: 0, max_depth: max_depth)
          puts
        end
      end

      def dump_value(value, depth: 0, max_depth: 3)
        indent = "  " * depth
        
        if depth >= max_depth
          puts "#{indent}[max depth reached]"
          return
        end

        case value
        when Hash
          if value.empty?
            puts "#{indent}{}"
          else
            value.each do |k, v|
              puts "#{indent}#{k}:"
              dump_value(v, depth: depth + 1, max_depth: max_depth)
            end
          end
        when Array
          if value.empty?
            puts "#{indent}[]"
          else
            value.each_with_index do |v, i|
              puts "#{indent}[#{i}]:"
              dump_value(v, depth: depth + 1, max_depth: max_depth)
            end
          end
        when Struct
          puts "#{indent}#{value.class}"
          value.each_pair do |k, v|
            puts "#{indent}  #{k}: #{v.inspect}"
          end
        when Module, Class
          puts "#{indent}#{value}"
        else
          puts "#{indent}#{value.inspect}"
        end
      end

      def dump_node_index(state, filter: nil)
        node_index = state[:node_index] || {}
        puts "=== NODE_INDEX ==="
        
        node_index.each do |oid, metadata|
          if filter.nil? || filter.call(metadata)
            puts "OID #{oid}:"
            metadata.each do |key, value|
              puts "  #{key}: #{value.inspect}"
            end
            puts
          end
        end
      end

      def dump_calls_only(state)
        dump_node_index(state) do |metadata|
          metadata[:expression_node]&.class&.name&.include?("CallExpression")
        end
      end
    end
  end
end