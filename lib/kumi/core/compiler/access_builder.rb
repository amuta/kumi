# frozen_string_literal: true

module Kumi
  module Core
    module Compiler
      class AccessBuilder
        def self.build(access_plans)
          new(access_plans).build
        end

        def initialize(access_plans)
          @access_plans = access_plans
          @accessors    = {}
        end

        def build
          @access_plans.each do |path_key, plan_list|
            plan_list.each do |plan|
              mode          = plan[:mode].to_sym
              missing       = (plan[:on_missing] || :error).to_sym
              key_policy    = (plan[:key_policy] || :indifferent).to_sym
              accessor_key  = "#{path_key}:#{mode}"
              ops           = plan[:operations]

              @accessors[accessor_key] =
                case mode
                when :each_indexed then build_each_accessor(ops, path_key, missing, key_policy)
                when :ravel        then build_ravel_accessor(ops, path_key, missing, key_policy)
                when :materialize  then build_materialize_accessor(ops, path_key, missing, key_policy)
                when :object       then build_object_accessor(ops, path_key, missing, key_policy)
                else
                  raise "Unsupported mode '#{mode}' for access plan at '#{path_key}'"
                end
            end
          end
          @accessors.freeze
        end

        private

        def fetch_key(hash, key, policy)
          case policy
          when :indifferent then hash[key] || hash[key.to_sym] || hash[key.to_s]
          when :string      then hash[key.to_s]
          when :symbol      then hash[key.to_sym]
          else hash[key]
          end
        end

        def assert_hash!(node, path_key, mode)
          raise TypeError, "Expected Hash at '#{path_key}' (#{mode})" unless node.is_a?(Hash)
        end

        def assert_array!(node, path_key, mode)
          raise TypeError, "Expected Array at '#{path_key}' (#{mode}); got #{node.class}" unless node.is_a?(Array)
        end

        def next_enters_array?(operations, pc)
          nxt = operations[pc + 1]
          nxt && nxt[:type] == :enter_array
        end

        # Returns one of :yield_nil, :skip, :raise
        def missing_key_action(policy)
          (if policy == :nil
             :yield_nil
           else
             policy == :skip ? :skip : :raise
           end)
        end

        def missing_array_action(policy)
          (if policy == :nil
             :yield_nil
           else
             policy == :skip ? :skip : :raise
           end)
        end

        def build_each_accessor(operations, path_key, policy, key_policy)
          walker = build_each_walker(operations, path_key, policy, key_policy)
          lambda do |data, &blk|
            enum = Enumerator.new { |y| walker.call(data, 0, [], y) }
            blk ? enum.each(&blk) : enum
          end
        end

        # Depth-first traversal yielding (value, nd_index)
        def build_each_walker(operations, path_key, policy, key_policy)
          mode = :each_indexed
          walker = nil
          walker = lambda do |node, pc, ndx, y|
            if pc >= operations.length
              y.yield(node, ndx)
              return
            end

            op = operations[pc]
            case op[:type]
            when :enter_hash
              assert_hash!(node, path_key, mode)
              policy_for = next_enters_array?(operations, pc) ? :indifferent : key_policy
              next_node = fetch_key(node, op[:key], policy_for)

              if next_node.nil?
                case missing_key_action(policy)
                when :yield_nil then y.yield(nil, ndx)
                when :skip      then return
                when :raise     then raise KeyError, "Missing key '#{op[:key]}' at '#{path_key}' (#{mode})"
                end
                return
              end
              walker.call(next_node, pc + 1, ndx, y)

            when :enter_array
              if node.nil?
                case missing_array_action(policy)
                when :yield_nil then y.yield(nil, ndx)
                when :skip      then return
                when :raise     then raise KeyError, "Missing array at '#{path_key}' (#{mode})"
                end
                return
              end
              assert_array!(node, path_key, mode)
              node.each_with_index { |child, i| walker.call(child, pc + 1, ndx + [i], y) }

            else
              raise "Unknown operation: #{op.inspect}"
            end
          end
        end

        def build_ravel_accessor(operations, path_key, policy, key_policy)
          mode = :ravel
          lambda do |data|
            out = []
            walk = nil
            walk = lambda do |node, pc|
              if pc >= operations.length
                out << node
                return
              end

              op = operations[pc]
              case op[:type]
              when :enter_hash
                policy_for = next_enters_array?(operations, pc) ? :indifferent : key_policy
                next_node = fetch_key(node, op[:key], policy_for)
                if next_node.nil?
                  case missing_key_action(policy)
                  when :yield_nil then out << nil
                  when :skip      then return
                  when :raise     then raise KeyError, "Missing key '#{op[:key]}' at '#{path_key}' (#{mode})"
                  end
                  return
                end
                walk.call(next_node, pc + 1)

              when :enter_array
                if node.nil?
                  case missing_array_action(policy)
                  when :yield_nil then out << nil
                  when :skip      then return
                  when :raise     then raise KeyError, "Missing array at '#{path_key}' (#{mode})"
                  end
                  return
                end
                assert_array!(node, path_key, mode)
                node.each { |child| walk.call(child, pc + 1) }

              else
                raise "Unknown operation: #{op.inspect}"
              end
            end
            walk.call(data, 0)
            out
          end
        end

        def build_materialize_accessor(operations, path_key, policy, key_policy)
          mode = :materialize
          lambda do |data|
            walk = nil
            walk = lambda do |node, pc|
              return node if pc >= operations.length

              op = operations[pc]
              case op[:type]
              when :enter_hash
                assert_hash!(node, path_key, mode)
                next_array = next_enters_array?(operations, pc)
                policy_for = next_array ? :indifferent : key_policy
                next_node = fetch_key(node, op[:key], policy_for)

                if next_node.nil?
                  case missing_key_action(policy)
                  when :yield_nil then return nil
                  when :skip      then return next_array ? [] : nil
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

        def build_object_accessor(operations, path_key, policy, key_policy)
          mode = :object
          lambda do |data|
            node = data
            operations.each do |op|
              case op[:type]
              when :enter_hash
                assert_hash!(node, path_key, mode)
                node = fetch_key(node, op[:key], key_policy)
                if node.nil?
                  case missing_key_action(policy)
                  when :yield_nil then return nil
                  when :skip      then return nil
                  when :raise     then raise KeyError, "Missing key '#{op[:key]}' at '#{path_key}' (#{mode})"
                  end
                end
              when :enter_array
                # Planner shouldn't emit :object for depth>0; treat as a hard shape error if it happens.
                raise TypeError, "Array encountered in :object accessor at '#{path_key}' (#{mode})"
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
