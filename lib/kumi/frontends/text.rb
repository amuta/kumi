# frozen_string_literal: true

module Kumi
  module Frontends
    module Text
      module_function

      # Load from a file path or a raw string.
      # Usage:
      #   Text.load(path: "schema.kumi", inputs: {...})
      #   Text.load(src: "...raw text...", inputs: {...})
      def load(path: nil, src: nil, inputs: {})
        raise ArgumentError, "provide either :path or :src" if (path.nil? && src.nil?) || (path && src)

        src ||= File.read(path)
        file_label = path || "(string)"

        begin
          require "kumi-parser"
          ast = Kumi::Parser::TextParser.parse(src)
          Core::Analyzer::Debug.info(:parse, kind: :text, file: file_label, ok: true) if Core::Analyzer::Debug.enabled?
          [ast, inputs]
        rescue LoadError
          raise "kumi-parser gem not available. Install: gem install kumi-parser"
        rescue StandardError => e
          loc = (e.respond_to?(:location) && e.location) || {}
          line, col = loc.values_at(:line, :column)
          snippet = code_frame(src, line, col)
          raise StandardError, "#{file_label}:#{line || '?'}:#{col || '?'}: #{e.message}\n#{snippet}"
        end
      end

      def self.code_frame(src, line, col, context: 2)
        return "" unless line

        lines  = src.lines
        from   = [line - 1 - context, 0].max
        to     = [line - 1 + context, lines.length - 1].min
        out    = []

        (from..to).each do |i|
          prefix = i + 1 == line ? "➤" : " "
          out << format("#{prefix} %4d | %s", i + 1, lines[i].rstrip)
          out << format("       | %s^", " " * (col - 1)) if i + 1 == line && col
        end

        out.join("\n")
      end
    end
  end
end
