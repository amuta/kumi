module Kumi
  module DocGenerator
    module Formatters
      class Markdown
        def initialize(docs)
          @docs = docs
        end

        def format
          lines = [
            "# Kumi Function Reference",
            "",
            "Auto-generated documentation for Kumi functions and their kernels.",
            ""
          ]

          grouped = group_by_id(@docs)

          grouped.sort.each do |id, aliases|
            entry = @docs[aliases.first]
            lines.concat(format_function(id, entry, aliases))
          end

          lines.join("\n")
        end

        private

        def group_by_id(docs)
          result = {}
          docs.each do |alias_name, entry|
            id = entry['id']
            result[id] ||= []
            result[id] << alias_name
          end
          result
        end

        def format_function(id, entry, aliases)
          lines = [
            "## `#{id}`",
            ""
          ]

          if aliases.length > 1
            lines << "**Aliases:** `#{aliases.sort.join('`, `')}`"
            lines << ""
          end

          lines << "- **Arity:** #{entry['arity']}"

          if entry['dtype']
            dtype_str = format_dtype(entry['dtype'])
            lines << "- **Type:** #{dtype_str}"
          end

          if is_reducer?(entry)
            lines << "- **Behavior:** Reduces a dimension `[D] -> T`"
          end
          lines << ""

          if entry['params'] && !entry['params'].empty?
            lines << "### Parameters"
            lines << ""
            entry['params'].each do |param|
              lines << "- `#{param['name']}`#{param['description'] ? ": #{param['description']}" : ""}"
            end
            lines << ""
          end

          if entry['kernels'] && !entry['kernels'].empty?
            lines << "### Implementations"
            lines << ""
            entry['kernels'].each do |target, kernel|
              lines.concat(format_kernel(target, kernel, entry['reduction_strategy']))
            end
          end

          lines
        end

        def format_kernel(target, kernel, reduction_strategy = nil)
          lines = []

          if kernel.is_a?(Hash)
            lines << "#### #{target.capitalize}"
            lines << ""
            lines << "`#{kernel['id']}`"
            lines << ""

            has_identity = kernel['identity'] && !kernel['identity'].empty?

            if kernel['inline'] && has_identity
              lines << "**Inline:** `#{escape_backticks(kernel['inline'])}` (`$0` = accumulator, `$1` = element)"
              lines << ""
            end

            if kernel['impl']
              lines << "**Implementation:**"
              lines << ""
              lines << "```ruby"
              lines << format_impl(kernel['impl'])
              lines << "```"
              lines << ""
            end

            if kernel['fold_inline']
              lines << "**Fold:** `#{escape_backticks(kernel['fold_inline'])}`"
              lines << ""
            end

            if has_identity
              lines << "**Identity:**"
              kernel['identity'].each do |type, value|
                lines << "- #{type}: `#{value}`"
              end
              lines << ""
            elsif kernel['inline']
              lines << "_Note: No identity value. First element initializes accumulator._"
              lines << ""
            end

            # Show reduction strategy if available
            if reduction_strategy
              case reduction_strategy
              when 'identity'
                lines << "**Reduction:** Monoid operation with identity element"
              when 'first_element'
                lines << "**Reduction:** First element is initial value (no identity)"
              else
                lines << "**Reduction:** #{reduction_strategy}"
              end
              lines << ""
            end
          else
            lines << "- **#{target}:** `#{kernel}`"
          end

          lines
        end

        def format_dtype(dtype)
          return "any" if dtype.nil?

          case dtype['rule']
          when 'same_as'
            "same as `#{dtype['param']}`"
          when 'scalar'
            dtype['kind'] || 'scalar'
          when 'promote'
            params = Array(dtype['params']).join('`, `')
            "promoted from `#{params}`"
          when 'element_of'
            "element of `#{dtype['param']}`"
          else
            dtype['rule']
          end
        end

        def format_impl(impl_str)
          # Clean up multiline strings like "(a,b)\n  a + b"
          impl_str.gsub('\n', "\n").strip
        end

        def escape_backticks(str)
          str.gsub('`', '\`')
        end

        def is_reducer?(entry)
          entry['kind'] == 'reduce'
        end
      end
    end
  end
end
