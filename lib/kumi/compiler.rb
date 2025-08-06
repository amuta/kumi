# frozen_string_literal: true

module Kumi
  # Compiles an analyzed schema into executable lambdas using registry-based broadcasting
  class Compiler
    def self.compile(schema, analyzer:)
      # Use the main Core::RubyCompiler directly
      puts "DEBUG: Using main Core::RubyCompiler with broadcast metadata" if ENV["DEBUG_COMPILER"]
      Core::RubyCompiler.new(schema, analyzer).compile
    end
  end
end
