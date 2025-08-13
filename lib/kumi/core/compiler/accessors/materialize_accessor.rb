# frozen_string_literal: true

module Kumi
  module Core
    module Compiler
      module Accessors
        class MaterializeAccessor
          extend Base

          def self.build(operations, path_key, policy, key_policy)
            mode = :materialize
            lambda do |data|
              walk = nil
              walk = lambda do |node, pc|
                return node if pc >= operations.length

                op = operations[pc]
                case op[:type]
                when :enter_hash
                  assert_hash!(node, path_key, mode)
                  preview_array = next_enters_array?(operations, pc)
                  policy_for = preview_array ? :indifferent : key_policy
                  next_node = fetch_key(node, op[:key], policy_for)
                  if next_node == Base::MISSING
                    case missing_key_action(policy)
                    when :yield_nil then return nil
                    when :skip      then return preview_array ? [] : nil
                    when :raise     then raise KeyError, "Missing key '#{op[:key]}' at '#{path_key}' (#{mode})"
                    end
                  end
                  walk.call(next_node, pc + 1)

                when :enter_array
                  if node.nil?
                    case missing_array_action(policy)
                    when :yield_nil then return nil
                    when :skip      then return []
                    when :raise     then raise KeyError, "Missing array at '#{path_key}' (#{mode})"
                    end
                  end
                  assert_array!(node, path_key, mode)
                  node.map { |child| walk.call(child, pc + 1) }

                else
                  raise "Unknown operation: #{op.inspect}"
                end
              end
              walk.call(data, 0)
            end
          end
        end
      end
    end
  end
end
