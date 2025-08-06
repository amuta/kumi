# frozen_string_literal: true

module Kumi
  module Core
    # ORCHESTRATOR: Initializes all compiler components and delegates compilation
    # tasks to specialized sub-compilers based on the operation type.
    class RubyCompiler
      def initialize(schema, analysis_result)
        @schema = schema
        @analysis = analysis_result
        @metadata = analysis_result.state[:detector_metadata] || {}
        @bindings = {}
        @index = {}
      end

      def compile
        # 1. Build an index of all declarations by name.
        build_index

        # 2. Build the optimized accessor lambdas for all input paths.
        accessors = build_accessors

        # 3. Initialize the central ExpressionBuilder with bindings and accessors.
        # This is now the single source of truth for compiling any expression.
        expression_builder = Core::Compiler::ExpressionBuilder.new(@bindings, accessors)

        # 4. Initialize the specialized compilers, giving them the expression_builder.
        compilers = build_specialized_compilers(expression_builder)

        # 5. Compile all declarations in their topologically sorted dependency order.
        @analysis.topo_order.each do |name|
          declaration = @index[name]
          declaration_meta = @metadata[name]
          op_type = declaration_meta&.[](:operation_type) || :scalar

          # Delegate to the appropriate sub-compiler.
          compiler = compilers[op_type]
          @bindings[name] = compiler.compile(declaration.expression, declaration_meta)
        end

        Core::CompiledSchema.new(@bindings.freeze)
      end

      private

      def build_index
        (@schema.attributes + @schema.traits).each { |decl| @index[decl.name] = decl }
      end

      def build_accessors
        input_metadata = @analysis.state[:inputs] || {}
        access_plans = Core::Compiler::AccessorPlanner.plan(input_metadata)
        Core::Compiler::AccessorBuilder.build(access_plans)
      end

      def build_specialized_compilers(expression_builder)
        {
          scalar: expression_builder, # The builder handles all scalar expressions
          vectorized: Core::Compiler::VectorizedOperationCompiler.new(expression_builder),
          reduction: Core::Compiler::ReductionOperationCompiler.new(expression_builder),
          array_reference: Core::Compiler::ArrayReferenceCompiler.new(expression_builder)
        }
      end
    end
  end
end
