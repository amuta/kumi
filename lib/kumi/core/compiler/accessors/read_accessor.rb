# frozen_string_literal: true

module Kumi
  module Core
    module Compiler
      module Accessors
        class ReadAccessor
          extend Base

          def self.build(operations, path_key, policy, key_policy)
            mode = :read
            lambda do |data|
              node = data
              operations.each do |op|
                case op[:type]
                when :enter_hash
                  assert_hash!(node, path_key, mode)
                  next_node = fetch_key(node, op[:key], key_policy)
                  if next_node == Base::MISSING
                    case missing_key_action(policy)
                    when :yield_nil then return nil
                    when :skip      then return nil
                    when :raise     then raise KeyError, "Missing key '#{op[:key]}' at '#{path_key}' (#{mode})"
                    end
                  end
                  node = next_node
                when :enter_array
                  # Should never be present for rank-0 plans
                  raise TypeError, "Array encountered in :read accessor at '#{path_key}'"
                else
                  raise "Unknown operation: #{op.inspect}"
                end
              end
              node
            end
          end
        end
      end
    end
  end
end
