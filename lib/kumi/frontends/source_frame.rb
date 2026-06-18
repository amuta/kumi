# frozen_string_literal: true

module Kumi
  module Frontends
    # Renders a parse/semantic error against its source as a `file:line:col`
    # header plus a caret-annotated code frame. The location is taken from the
    # error's structured `Location` when present; we no longer scrape it out of
    # the message text, which is what produced the flaky `?:?` headers.
    module SourceFrame
      module_function

      # Build the full user-facing error string for `error` raised while loading
      # `src` labelled `file_label`. When the error carries a usable location we
      # emit `file:line:col: message` and a code frame; when it does not, we emit
      # a clean `file: message` with no invented coordinates.
      def render(error, src:, file_label:)
        loc = location_of(error)
        message = clean_message(error.message)
        return "#{file_label}: #{message}" unless loc

        # Render the header through Location#to_s (the one location dialect),
        # substituting the caller's file label for the path.
        header = "#{Kumi::Syntax::Location.new(file: file_label, line: loc.line, column: loc.column)}: #{message}"
        frame = code_frame(src, loc.line, loc.column)
        frame.empty? ? header : "#{header}\n#{frame}"
      end

      # The structured location, if the error exposes a line and column. Both
      # Kumi's LocatedError and the parser's SyntaxError satisfy this; anything
      # else falls through to nil rather than a guessed coordinate.
      def location_of(error)
        return nil unless error.respond_to?(:location)

        loc = error.location
        return nil unless loc.respond_to?(:line)
        return nil if loc.line.nil?

        loc
      end

      # Strip the canonical `file:line:col:` / `file:line:` location prefix the
      # message may already carry (LocatedError#to_s and ErrorEntry#to_s both
      # prepend it), so render adds the header exactly once. Now that every
      # location renders one way, this is a single prefix to remove.
      def clean_message(message)
        message.to_s.sub(/\A\S+:\d+(?::\d+)?:\s+/, "").strip
      end

      def code_frame(src, line, col, context: 2)
        return "" if line.nil?

        lines = src.lines
        return "" if lines.empty?

        from = [line - 1 - context, 0].max
        to   = [line - 1 + context, lines.length - 1].min
        (from..to).flat_map { |i| frame_row(lines[i], i + 1, line, col) }.join("\n")
      end

      # The source line plus, when it is the target line and we know the column,
      # a caret pointer beneath it. Column 0/nil means "column unknown" — skip it.
      def frame_row(text, number, target_line, col)
        marker = number == target_line ? "➤" : " "
        row = format("%s %4d | %s", marker, number, text.to_s.rstrip)
        return [row] unless number == target_line && col && col >= 1

        [row, format("       | %s^", " " * (col - 1))]
      end
    end
  end
end
