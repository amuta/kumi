# frozen_string_literal: true

module Kumi
  # Compiles an analyzed schema into executable lambdas
  class Compiler < Core::CompilerBase
    include Kumi::Core::Compiler::ReferenceCompiler
    include Kumi::Core::Compiler::PathTraversalCompiler
    include Kumi::Core::Compiler::ExpressionCompiler
    include Kumi::Core::Compiler::FunctionInvoker

    def self.compile(schema, analyzer:)
      new(schema, analyzer).compile
    end

    def initialize(schema, analyzer)
      super
      @bindings = {}
    end

    def compile
      # Switch to LIR: Use the analysis state instead of old compilation
      Runtime::Program.from_analysis(@analysis.state)
    end
  end
end
