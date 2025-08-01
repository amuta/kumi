# frozen_string_literal: true

module Kumi::Core
  module RubyParser
    module Dsl
      def self.build_syntax_tree(&rule_block)
        parser = Parser.new
        parser.parse(&rule_block)
      end
    end
  end
end
