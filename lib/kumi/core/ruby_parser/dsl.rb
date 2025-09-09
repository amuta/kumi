# frozen_string_literal: true

module Kumi
  module Core
    module RubyParser
      module Dsl
        def self.build_syntax_tree(&)
          parser = Parser.new
          parser.parse(&)
        end
      end
    end
  end
end
