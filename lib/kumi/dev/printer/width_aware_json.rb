require "json"

module Kumi
  module Dev
    module Printer
      module WidthAwareJson
        module_function

        def dump(obj, max: 120, indent: 0)
          # First try a compact one-liner
          one = JSON.generate(obj)
          return one if one.size <= max

          case obj
          when Array
            items = obj.map { |v| dump(v, max: max, indent: indent + 2) }
            join_multiline("[", items, "]", indent)
          when Hash
            items = obj.map do |k, v|
              key = JSON.generate(k)
              val = dump(v, max: max, indent: indent + 2)
              "#{key}: #{val}"
            end
            join_multiline("{", items, "}", indent)
          else
            one # scalars just return compact
          end
        end

        def join_multiline(open, items, close, indent)
          pad = " " * (indent + 2)
          [
            open,
            pad + items.join(",\n" + pad),
            (" " * indent) + close
          ].join("\n")
        end
      end

      # Usage:
      # puts WidthAwareJSON.dump(ir_hash, max: 140)
    end
  end
end
