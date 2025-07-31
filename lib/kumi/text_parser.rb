# frozen_string_literal: true

require_relative "text_parser/parser"

module Kumi
  module TextParser
    # Parse text DSL and return the same AST as Ruby DSL
    def self.parse(text_dsl, source_file: "<text_parser>")
      ParsletParser.new.parse(text_dsl, source_file: source_file)
    end
  end
end