# frozen_string_literal: true

module Kumi
  # Compiles an analyzed schema into executable lambdas
  class Compiler < Core::CompilerBase
    def self.compile(schema, analyzer:)
      new(schema, analyzer).compile
    end

    def initialize(schema, analyzer)
      super
      @bindings = {}
    end

    def compile
      # Switch to LIR: Use the analysis state instead of old compilation
      Runtime::Executable.from_analysis(@analysis.state)
    end
  end
end
