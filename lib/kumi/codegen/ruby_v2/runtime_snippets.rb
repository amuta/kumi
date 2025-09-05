# frozen_string_literal: true

module Kumi
  module Codegen
    module RubyV2
      module RuntimeSnippets
        module_function

        def helpers_block(policy_map:)
          <<~RUBY
            # === PRIVATE RUNTIME HELPERS (cursor-based, strict) ===
            MISSING_POLICY = #{policy_map.inspect}.freeze

            private

            def __fetch_key__(obj, key)
              return nil if obj.nil?
              if obj.is_a?(Hash)
                obj.key?(key) ? obj[key] : obj[key.to_sym]
              else
                obj.respond_to?(key) ? obj.public_send(key) : nil
              end
            end

            def __array_of__(obj, key)
              arr = __fetch_key__(obj, key)
              return arr if arr.is_a?(Array)
              policy = MISSING_POLICY.fetch(key) { raise "No missing data policy defined for key '\#{key}' in pack capabilities" }
              case policy
              when :empty then []
              when :skip  then nil
              else
                raise KeyError, "expected Array at \#{key.inspect}, got \#{arr.class}"
              end
            end

            def __each_array__(obj, key)
              arr = __array_of__(obj, key)
              return if arr.nil?
              i = 0
              while i < arr.length
                yield arr[i]
                i += 1
              end
            end

            def __walk__(steps, root, cursors)
              cur = root
              steps.each do |s|
                case s["kind"]
                when "array_field"
                  if (ax = s["axis"]) && cursors.key?(ax)
                    cur = cursors[ax]
                  else
                    cur = __fetch_key__(cur, s["key"])
                    raise KeyError, "missing key \#{s["key"].inspect}" if cur.nil?
                  end
                when "field_leaf"
                  cur = __fetch_key__(cur, s["key"])
                  raise KeyError, "missing key \#{s["key"].inspect}" if cur.nil?
                when "array_element"
                  ax = s["axis"]; raise KeyError, "missing cursor for \#{ax}" unless cursors.key?(ax)
                  cur = cursors[ax]
                when "element_leaf"
                  # no-op
                else
                  raise KeyError, "unknown step kind: \#{s["kind"]}"
                end
              end
              cur
            end
          RUBY
        end
      end
    end
  end
end
