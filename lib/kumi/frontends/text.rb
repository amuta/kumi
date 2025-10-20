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
        file_label = path || "schema"

        begin
          require "kumi-parser"
          ast = Kumi::Parser::TextParser.parse(src, source_file: path || "schema")
          Core::Analyzer::Debug.info(:parse, kind: :text, file: file_label, ok: true) if Core::Analyzer::Debug.enabled?
          [ast, inputs]
        rescue LoadError
          raise "kumi-parser gem not available. Install: gem install kumi-parser"
        rescue StandardError => e
          # Try to extract line/column from exception object first
          line, col = extract_line_column(e)
          snippet = code_frame(src, line, col)

          # Strip file:line:col prefix from e.message if it exists (from parser)
          # Also strip embedded "at FILE line=N column=M" to avoid duplication
          error_message = e.message
            .sub(/^\S+:\d+:\d+:\s+/, '')
            .gsub(/\s+at\s+\S+\s+line=\d+\s+column=\d+/, '')
            .strip
          raise StandardError, "#{file_label}:#{line || '?'}:#{col || '?'}: #{error_message}\n#{snippet}"
        end
      end

      def self.extract_line_column(exception)
        # Try to access Location object from exception
        if exception.respond_to?(:location) && exception.location
          loc = exception.location
          if loc.respond_to?(:line) && loc.respond_to?(:column)
            return [loc.line, loc.column]
          end
        end

        # Fall back to parsing error message if no Location object
        extract_line_column_from_message(exception.message)
      end

      def self.extract_line_column_from_message(message)
        if message =~ /line=(\d+)\s+column=(\d+)/
          [::Regexp.last_match(1).to_i, ::Regexp.last_match(2).to_i]
        else
          [nil, nil]
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
