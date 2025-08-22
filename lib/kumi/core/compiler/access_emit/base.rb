# frozen_string_literal: true
module Kumi
  module Core
    module Compiler
      module AccessEmit
        module Base
          module_function

          # ---------- IR segmentation ----------
          def segment_ops(ops)
            segs, cur = [], []
            i = 0
            while i < ops.length
              case ops[i][:type]
              when :enter_hash
                preview = (i + 1 < ops.length) && ops[i + 1][:type] == :enter_array
                cur << [:enter_hash, ops[i][:key].to_s, preview]
              when :enter_array
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

          # ---------- codegen helpers ----------
          def fetch_hash_code(node_var:, key:, key_policy:, preview_array:, mode:, policy:, path_key:, map_depth:)
            effective_policy = preview_array ? :indifferent : (key_policy || :indifferent)
            str = key.to_s.inspect
            sym = key.to_sym.inspect

            fetch =
              case effective_policy
              when :string
                %(next_node = #{node_var}.key?(#{str}) ? #{node_var}[#{str}] : :__missing__)
              when :symbol
                %(next_node = #{node_var}.key?(#{sym}) ? #{node_var}[#{sym}] : :__missing__)
              else # :indifferent
                <<~RB.chomp
                  next_node =
                    if #{node_var}.key?(#{str}); #{node_var}[#{str}]
                    elsif #{node_var}.key?(#{sym}); #{node_var}[#{sym}]
                    elsif #{node_var}.key?(#{str}); #{node_var}[#{str}] # (string twice ok / predictable)
                    else :__missing__
                    end
                RB
              end

            miss_action = build_miss_action(policy, mode, map_depth, preview_array, key: key, path_key: path_key)

            <<~RB.chomp
              raise TypeError, "Expected Hash at '#{path_key}' (#{mode})" unless #{node_var}.is_a?(Hash)
              #{fetch}
              if next_node == :__missing__
                #{miss_action}
              end
              #{node_var} = next_node
            RB
          end

          def array_guard_code(node_var:, mode:, policy:, path_key:, map_depth:)
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

          # ---------- missing behaviors ----------
          def build_miss_action(policy, mode, map_depth, preview_array, key:, path_key:)
            case policy
            when :nil
              if mode == :ravel
                base = "out << nil"
                cont = map_depth.positive? ? "next" : "return out"
                "#{base}\n#{cont}"
              elsif mode == :each_indexed
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
              else # :materialize, :read
                # Important: for :materialize this is ALWAYS nil (never [])
                return_val = 'nil'
                map_depth.positive? ? "next #{return_val}" : "return #{return_val}"
              end
            when :skip
              if mode == :materialize
                return_val = preview_array ? '[]' : 'nil'
                map_depth.positive? ? "next #{return_val}" : "return #{return_val}"
              else
                map_depth.positive? ? "next" : (mode == :each_indexed ? "if block; return nil; else; return out; end" : "return out")
              end
            else # :error
              %(raise KeyError, "Missing key '#{key}' at '#{path_key}' (#{mode})")
            end
          end

          def build_array_miss_action(policy, mode, map_depth, path_key)
            case policy
            when :nil
              if mode == :materialize
                map_depth.positive? ? "next nil" : "return nil"
              elsif mode == :each_indexed
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
              else # :ravel / others
                base = "out << nil"
                cont = map_depth.positive? ? "next" : "return out"
                "#{base}\n#{cont}"
              end
            when :skip
              if mode == :materialize
                map_depth.positive? ? "next []" : "return []"
              elsif mode == :each_indexed
                map_depth.positive? ? "next" : "if block; return nil; else; return out; end"
              else # :ravel
                map_depth.positive? ? "next" : "return out"
              end
            else
              %(raise TypeError, "Missing array at '#{path_key}' (#{mode})")
            end
          end
        end
      end
    end
  end
end