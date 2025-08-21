# frozen_string_literal: true

module Kumi
  module Core
    module Compiler
      module AccessEmit
        # ---------- helpers ----------
        def self.segment_ops(ops)
          # => [ [ [[:enter_hash, "players", preview_array?], ...], :array, [[:enter_hash, ...], ...], :array, ... ] ]
          segs = []
          i = 0
          cur = []
          while i < ops.length
            if ops[i][:type] == :enter_hash
              preview = (i + 1 < ops.length) && ops[i + 1][:type] == :enter_array
              cur << [:enter_hash, ops[i][:key].to_s, preview]
            elsif ops[i][:type] == :enter_array
              segs << cur unless cur.empty?
              segs << :array
              cur = []
            else
              raise "Unknown operation: #{ops[i].inspect}"
            end
            i += 1
          end
          segs << cur unless cur.empty?
          segs
        end

        def self.fetch_hash_code(node_var:, key:, key_policy:, preview_array:, mode:, policy:, path_key:, map_depth:)
          # force indifferent if previewing an array hop (matches Accessors)
          effective_policy = preview_array ? :indifferent : (key_policy || :indifferent)
          sym_lit  = key.to_sym.inspect
          str_lit  = key.to_s.inspect

          fetch =
            case effective_policy
            when :string
              %(next_node = #{node_var}.key?(#{str_lit}) ? #{node_var}[#{str_lit}] : :__missing__)
            when :symbol
              %(next_node = #{node_var}.key?(#{sym_lit}) ? #{node_var}[#{sym_lit}] : :__missing__)
            else # :indifferent
              <<~RB.chomp
                next_node =
                  if #{node_var}.key?(#{str_lit}); #{node_var}[#{str_lit}]
                  elsif #{node_var}.key?(#{sym_lit}); #{node_var}[#{sym_lit}]
                  else :__missing__
                  end
              RB
            end

          miss_action = build_miss_action(policy, mode, map_depth, preview_array)

          <<~RB.chomp
            raise TypeError, "Expected Hash at '#{path_key}' (#{mode})" unless #{node_var}.is_a?(Hash)
            #{fetch}
            if next_node == :__missing__
              #{miss_action}
            end
            #{node_var} = next_node
          RB
        end

        def self.array_guard_code(node_var:, mode:, policy:, path_key:, map_depth:)
          miss_action = build_array_miss_action(policy, mode, map_depth, path_key)

          <<~RB.chomp
            if #{node_var}.nil?
              #{miss_action}
            end
            unless #{node_var}.is_a?(Array)
              raise TypeError, "Expected Array at '#{path_key}' (#{mode}); got \#{#{node_var}.class}"
            end
          RB
        end

        # ---------- READ (unchanged logic) ----------
        def self.read(plan)
          policy     = plan.on_missing || :error
          key_policy = plan.key_policy || :indifferent
          path_key   = plan.path
          ops        = plan.operations

          ops_code = ops.map do |op|
            case op[:type]
            when :enter_hash
              fetch_hash_code(node_var: "node", key: op[:key], key_policy: key_policy,
                              preview_array: false, mode: :read, policy: policy,
                              path_key: path_key, map_depth: 0)
            when :enter_array
              %(raise TypeError, "Array encountered in :read accessor at '#{path_key}'")
            end
          end.join("\n      ")

          <<~RUBY
            lambda do |data|
              node = data
              #{ops_code}
              node
            end
          RUBY
        end

        # ---------- MATERIALIZE (nested maps) ----------
        def self.materialize(plan)
          policy     = plan.on_missing || :error
          key_policy = plan.key_policy || :indifferent
          path_key   = plan.path
          segs       = segment_ops(plan.operations)

          code = +"lambda do |data|\n"
          nodev = "node0"
          depth = 0
          map_depth = 0
          code << "  #{nodev} = data\n"
          
          segs.each do |seg|
            if seg == :array
              code << "  #{array_guard_code(node_var: nodev, mode: :materialize, policy: policy, path_key: path_key, map_depth: map_depth)}\n"
              # open map block
              child = "node#{depth + 1}"
              code << "  #{nodev} = #{nodev}.map do |__e#{depth}|\n"
              code << "    #{child} = __e#{depth}\n"
              nodev = child
              depth += 1
              map_depth += 1
            else
              seg.each do |(_, key, preview)|
                code << "  "
                code << fetch_hash_code(node_var: nodev, key: key, key_policy: key_policy,
                                        preview_array: preview, mode: :materialize, policy: policy,
                                        path_key: path_key, map_depth: map_depth)
                code << "\n"
              end
            end
          end

          # close all open maps, returning last node
          while map_depth.positive?
            code << "  " * map_depth + "#{nodev}\n"
            code << "  " * (map_depth - 1) + "end\n"
            nodev = "node#{depth - 1}"
            depth -= 1
            map_depth -= 1
          end
          code << "  #{nodev}\n"
          code << "end\n"
          code
        end

        # ---------- RAVEL (nested loops, collect leaves) ----------
        def self.ravel(plan)
          policy     = plan.on_missing || :error
          key_policy = plan.key_policy || :indifferent
          path_key   = plan.path
          segs       = segment_ops(plan.operations) # planner guarantees terminal :enter_array so last seg is :array

          code = +"lambda do |data|\n"
          code << "  out = []\n"
          nodev = "node0"
          depth = 0
          loop_depth = 0
          code << "  #{nodev} = data\n"

          segs.each do |seg|
            if seg == :array
              code << "  #{array_guard_code(node_var: nodev, mode: :ravel, policy: policy, path_key: path_key, map_depth: loop_depth)}\n"
              code << "  ary#{loop_depth} = #{nodev}\n"
              code << "  len#{loop_depth} = ary#{loop_depth}.length\n"
              code << "  i#{loop_depth} = -1\n"
              code << "  while (i#{loop_depth} += 1) < len#{loop_depth}\n"
              child = "node#{depth + 1}"
              code << "    #{child} = ary#{loop_depth}[i#{loop_depth}]\n"
              nodev = child
              depth += 1
              loop_depth += 1
            else
              seg.each do |(_, key, preview)|
                code << "  "
                code << fetch_hash_code(node_var: nodev, key: key, key_policy: key_policy,
                                        preview_array: preview, mode: :ravel, policy: policy,
                                        path_key: path_key, map_depth: loop_depth)
                code << "\n"
              end
            end
          end

          # leaf: push value
          code << "  out << #{nodev}\n"
          while loop_depth.positive?
            code << "  end\n"
            loop_depth -= 1
            nodev = "node#{depth - 1}"
            depth -= 1
          end

          code << "  out\n"
          code << "end\n"
          code
        end

        # ---------- EACH_INDEXED (nested loops + idx vector) ----------
        def self.each_indexed(plan)
          policy     = plan.on_missing || :error
          key_policy = plan.key_policy || :indifferent
          path_key   = plan.path
          segs       = segment_ops(plan.operations) # planner guarantees terminal :enter_array

          code = +"lambda do |data, &block|\n"
          code << "  out = []\n"
          code << "  node0 = data\n"
          code << "  idx_vec = []\n"
          nodev = "node0"
          depth = 0
          loop_depth = 0

          segs.each do |seg|
            if seg == :array
              code << "  #{array_guard_code(node_var: nodev, mode: :each_indexed, policy: policy, path_key: path_key, map_depth: loop_depth)}\n"
              code << "  ary#{loop_depth} = #{nodev}\n"
              code << "  len#{loop_depth} = ary#{loop_depth}.length\n"
              code << "  i#{loop_depth} = -1\n"
              code << "  while (i#{loop_depth} += 1) < len#{loop_depth}\n"
              code << "    idx_vec[#{loop_depth}] = i#{loop_depth}\n"
              child = "node#{depth + 1}"
              code << "    #{child} = ary#{loop_depth}[i#{loop_depth}]\n"
              nodev = child
              depth += 1
              loop_depth += 1
            else
              seg.each do |(_, key, preview)|
                code << fetch_hash_code(node_var: nodev, key: key, key_policy: key_policy,
                                        preview_array: preview, mode: :each_indexed, policy: policy,
                                        path_key: path_key, map_depth: loop_depth)
                code << "\n"
              end
            end
          end

          # leaf: yield/collect [value, idx_vec]
          code << "  if block\n"
          code << "    block.call(#{nodev}, idx_vec.dup)\n"
          code << "  else\n"
          code << "    out << [#{nodev}, idx_vec.dup]\n"
          code << "  end\n"

          while loop_depth.positive?
            code << "  end\n"
            loop_depth -= 1
            nodev = "node#{depth - 1}"
            depth -= 1
          end

          code << "  block ? nil : out\n"
          code << "end\n"
          code
        end

        private_class_method def self.build_miss_action(policy, mode, map_depth, preview_array)
          case policy
          when :nil
            # ravel/each_indexed push/yield nil & continue; materialize returns nil or [] if previewing array
            case mode
            when :materialize
              return_val = preview_array ? '[]' : 'nil'
              map_depth.positive? ? "next #{return_val}" : "return #{return_val}"
            when :ravel
              base = "out << nil"
              continue_action = map_depth.positive? ? "next" : "return out"
              "#{base}\n#{continue_action}"
            when :each_indexed
              build_each_indexed_nil_action(map_depth)
            else # :read shouldn't come here in practice for vector paths
              map_depth.positive? ? "next nil" : "return nil"
            end
          when :skip
            build_skip_action(mode, map_depth, preview_array)
          else # :error
            "raise KeyError, \"Missing key at path (#{mode})\""
          end
        end

        private_class_method def self.build_each_indexed_nil_action(map_depth)
          if map_depth.positive?
            <<~RB.chomp
              if block
                block.call(nil, idx_vec.dup)
                next
              else
                out << [nil, idx_vec.dup]
                next
              end
            RB
          else
            <<~RB.chomp
              if block
                block.call(nil, idx_vec.dup)
                return nil
              else
                out << [nil, idx_vec.dup]
                return out
              end
            RB
          end
        end

        private_class_method def self.build_skip_action(mode, map_depth, preview_array)
          case mode
          when :materialize
            return_val = preview_array ? '[]' : 'nil'
            map_depth.positive? ? "next #{return_val}" : "return #{return_val}"
          when :ravel
            map_depth.positive? ? "next" : "return out"
          when :each_indexed
            if map_depth.positive?
              "next"
            else
              "if block; return nil; else; return out; end"
            end
          else
            map_depth.positive? ? "next" : "return nil"
          end
        end

        private_class_method def self.build_array_miss_action(policy, mode, map_depth, path_key)
          case policy
          when :nil
            case mode
            when :materialize
              map_depth.positive? ? "next []" : "return []"
            when :ravel
              base = "out << nil"
              continue_action = map_depth.positive? ? "next" : "return out"
              "#{base}\n#{continue_action}"
            when :each_indexed
              build_each_indexed_nil_action(map_depth)
            else
              map_depth.positive? ? "next nil" : "return nil"
            end
          when :skip
            case mode
            when :materialize then map_depth.positive? ? "next []" : "return []"
            when :ravel       then map_depth.positive? ? "next" : "return out"
            when :each_indexed
              if map_depth.positive?
                "next"
              else
                "if block; return nil; else; return out; end"
              end
            else
              map_depth.positive? ? "next" : "return nil"
            end
          else
            %(raise TypeError, "Missing array at '#{path_key}' (#{mode})")
          end
        end
      end
    end
  end
end