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
      build_index
      @analysis.topo_order.each do |name|
        decl = @index[name] or raise("Unknown binding #{name}")
        compile_declaration(decl)
      end

      Core::CompiledSchema.new(@bindings.freeze)
    end
  end
end
