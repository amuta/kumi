# frozen_string_literal: true

module Kumi
  # Compiles an analyzed schema into executable lambdas
  class Compiler < Core::CompilerBase
    def self.compile(schema, analyzer:, schema_name: nil)
      new(schema, analyzer, schema_name: schema_name).compile
    end

    def initialize(schema, analyzer, schema_name: nil)
      super(schema, analyzer)
      @bindings = {}
      @schema_name = schema_name
    end

    def compile
      # Switch to LIR: Use the analysis state instead of old compilation
      Runtime::Executable.from_analysis(@analysis.state, schema_name: @schema_name)
    end
  end
end
