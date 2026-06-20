# frozen_string_literal: true

require_relative "source_frame"

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
          ast = Kumi::Parser::TextParser.parse(src, source_file: file_label)
          Core::Analyzer::Debug.info(:parse, kind: :text, file: file_label, ok: true) if Core::Analyzer::Debug.enabled?
          [ast, inputs]
        rescue LoadError
          raise "kumi-parser gem not available. Install: gem install kumi-parser"
        rescue StandardError => e
          raise StandardError, SourceFrame.render(e, src: src, file_label: file_label)
        end
      end
    end
  end
end
