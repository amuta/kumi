# frozen_string_literal: true

module Kumi
  module Core
    module Compiler
      module Accessors
        module Base
          MISSING = :__missing__

          # -------- assertions --------
          def assert_hash!(node, path_key, mode)
            raise TypeError, "Expected Hash at '#{path_key}' (#{mode})" unless node.is_a?(Hash)
          end

          def assert_array!(node, path_key, mode)
            return if node.is_a?(Array)

            warn_mismatch(node, path_key) if ENV["DEBUG_ACCESS_BUILDER"]
            raise TypeError, "Expected Array at '#{path_key}' (#{mode}); got #{node.class}"
          end

          def warn_mismatch(node, path_key)
            puts "DEBUG AccessBuilder error at #{path_key}: got #{node.class}, value=#{node.inspect}"
          end

          # -------- key fetch with policy --------
          def fetch_key(hash, key, policy)
            case policy
            when :indifferent
              return hash[key] if hash.key?(key)
              return hash[key.to_sym] if hash.key?(key.to_sym)
              return hash[key.to_s]   if hash.key?(key.to_s)

              MISSING
            when :string
              hash.key?(key.to_s) ? hash[key.to_s] : MISSING
            when :symbol
              hash.key?(key.to_sym) ? hash[key.to_sym] : MISSING
            else
              hash.key?(key) ? hash[key] : MISSING
            end
          end

          # -------- op helpers --------
          def next_enters_array?(operations, pc)
            nxt = operations[pc + 1]
            nxt && nxt[:type] == :enter_array
          end

          def missing_key_action(policy)
            if policy == :nil
              :yield_nil
            else
              (policy == :skip ? :skip : :raise)
            end
          end

          def missing_array_action(policy)
            if policy == :nil
              :yield_nil
            else
              (policy == :skip ? :skip : :raise)
            end
          end
        end
      end
    end
  end
end
