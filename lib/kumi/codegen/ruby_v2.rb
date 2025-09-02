# frozen_string_literal: true

require_relative "ruby_v2/generator"

module Kumi
  module Codegen
    module RubyV2
      def self.generate(pack, module_name:)
        Generator.new(pack, module_name: module_name).render
      end
    end
  end
end