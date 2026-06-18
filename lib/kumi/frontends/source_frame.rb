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

        if loc
          frame = code_frame(src, loc.line, loc.column)
          # Column 0 means "line known, column unknown" (the Ruby frontend can't
          # recover columns from caller_locations) — omit it rather than print `:0`.
          header = if loc.column && loc.column >= 1
                     "#{file_label}:#{loc.line}:#{loc.column}: #{message}"
                   else
                     "#{file_label}:#{loc.line}: #{message}"
                   end
          frame.empty? ? header : "#{header}\n#{frame}"
        else
          "#{file_label}: #{message}"
        end
      end

      # The structured location, if the error exposes a line and column. Both
      # Kumi's LocatedError and the parser's SyntaxError satisfy this; anything
      # else falls through to nil rather than a guessed coordinate.
      def location_of(error)
        return nil unless error.respond_to?(:location)

        loc = error.location
        return nil unless loc.respond_to?(:line) && loc.respond_to?(:column)
        return nil if loc.line.nil? || loc.column.nil?

        loc
      end

      # Strip any location the message already carries so the header renders it
      # exactly once. Messages may arrive with a leading `file:line:col:` prefix,
      # a leading `at FILE line=N column=M:` prefix (ErrorReporter's form), and/or
      # a trailing `at FILE line=N column=M` suffix (LocatedError#to_s).
      def clean_message(message)
        message.to_s
               .sub(/\A\S+:\d+:\d+:\s+/, "")
               .sub(/\Aat\s+\S+\s+line=\d+\s+column=\d+:\s+/, "")
               .gsub(/\s+at\s+\S+\s+line=\d+\s+column=\d+/, "")
               .strip
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
