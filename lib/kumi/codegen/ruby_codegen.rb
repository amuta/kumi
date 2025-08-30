# frozen_string_literal: true

require_relative "ruby"

module Kumi
  module Codegen
    class RubyCodegen
      def self.generate(ir_file, binding_manifest_file, options = {})
        Ruby.generate(ir_file, binding_manifest_file, options)
      end
    end
  end
end
