# frozen_string_literal: true

module Kumi
  module Core
    module Compiler
      module Accessors
        class EachIndexedAccessor
          extend Base

          def self.build(operations, path_key, policy, key_policy, with_indices = true)
            walker = build_each_walker(operations, path_key, policy, key_policy)
            if with_indices
              lambda do |data, &blk|
                if blk
                  walker.call(data, 0, [], ->(val, idx) { blk.call(val, idx) })
                  nil
                else
                  out = []
                  walker.call(data, 0, [], ->(val, idx) { out << [val, idx] })
                  out
                end
              end
            else
              lambda do |data, &blk|
                if blk
                  walker.call(data, 0, [], ->(val, _idx) { blk.call(val) })
                  nil
                else
                  out = []
                  walker.call(data, 0, [], ->(val, _idx) { out << val })
                  out
                end
              end
            end
          end

          # Depth-first traversal yielding (value, nd_index)
          def self.build_each_walker(operations, path_key, policy, key_policy)
            mode = :each_indexed
            walk = nil
            walk = lambda do |node, pc, ndx, y|
              if pc >= operations.length
                y.call(node, ndx)
                return
              end

              op = operations[pc]
              case op[:type]
              when :enter_hash
                # If the *next* op is an array hop, relax to indifferent for that fetch
                policy_for = next_enters_array?(operations, pc) ? :indifferent : key_policy
                next_node = fetch_key(node, op[:key], policy_for)
                if next_node == Base::MISSING
                  case missing_key_action(policy)
                  when :yield_nil then y.call(nil, ndx)
                  when :skip      then return
                  when :raise     then raise KeyError, "Missing key '#{op[:key]}' at '#{path_key}' (#{mode})"
                  end
                  return
                end
                walk.call(next_node, pc + 1, ndx, y)

              when :enter_array
                if node.nil?
                  case missing_array_action(policy)
                  when :yield_nil then y.call(nil, ndx)
                  when :skip      then return
                  when :raise     then raise KeyError, "Missing array at '#{path_key}' (#{mode})"
                  end
                  return
                end
                assert_array!(node, path_key, mode)
                node.each_with_index { |child, i| walk.call(child, pc + 1, ndx + [i], y) }

              else
                raise "Unknown operation: #{op.inspect}"
              end
            end
          end
        end
      end
    end
  end
end
