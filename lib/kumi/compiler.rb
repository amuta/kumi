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
      # Pre-build function registry to avoid repeated RegistryV2 loading at execution time
      ir_module = @analysis.state.fetch(:ir_module)
      function_registry = Core::IR::FunctionExtractor.build_function_hash(ir_module)
      
      # Switch to LIR: Use the analysis state with pre-built registry
      Runtime::Executable.from_analysis(@analysis.state, registry: function_registry)
    end
  end
end
