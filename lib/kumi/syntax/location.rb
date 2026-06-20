module Kumi
  module Syntax
    # The single source of truth for how a source location is rendered. Every
    # error message and code frame formats locations through here so the codebase
    # speaks one dialect: the editor-clickable `file:line:col` form. Do not
    # hand-roll `"at file line=N column=M"` strings elsewhere — call #to_s.
    class Location < Struct.new(:file, :line, :column, keyword_init: true)
      # Canonical `file:line:col` rendering. A zero/nil column is omitted (the
      # column is unknown rather than column 0), giving a clean `file:line`.
      def to_s
        return "#{file}:#{line}:#{column}" if column&.positive?

        "#{file}:#{line}"
      end

      # True when there is enough to point a user at a real spot in their source.
      def usable?
        !file.nil? && !line.nil? && line.positive?
      end
    end
  end
end
