# frozen_string_literal: true

require "ostruct"

module Kumi
  module Core
    # Clean compiler that uses broadcast detector metadata for pure translation
    class RubyCompiler
      def initialize(schema, analysis_result)
        @schema = schema
        @analysis = analysis_result
        @metadata = analysis_result.state[:detector_metadata] || {}
        @bindings = {}
        @index = {}
        @accessors = {}
      end

      def compile
        build_index
        build_accessors # Build smart accessor procs

        # Compile in dependency order
        @analysis.topo_order.each do |name|
          decl = @index[name] or raise("Unknown binding #{name}")
          @bindings[name] = compile_declaration(name, decl)
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
        @accessors = Core::Compiler::AccessorBuilder.build(access_plans)

        # Build argument extractors for registry functions
        @arg_extractors = build_argument_extractors

        puts "DEBUG: Built accessors: #{@accessors.keys}" if ENV["DEBUG_COMPILER"]
      end

      def build_argument_extractors
        {
          array_scalar_object: Core::Compiler::RegistryArgumentBuilder.build_argument_extractor(:array_scalar_object),
          element_wise_object: Core::Compiler::RegistryArgumentBuilder.build_argument_extractor(:element_wise_object),
          parent_child_object: Core::Compiler::RegistryArgumentBuilder.build_argument_extractor(:parent_child_object),
          array_scalar_vector: Core::Compiler::RegistryArgumentBuilder.build_argument_extractor(:array_scalar_vector),
          element_wise_vector: Core::Compiler::RegistryArgumentBuilder.build_argument_extractor(:element_wise_vector),
          parent_child_vector: Core::Compiler::RegistryArgumentBuilder.build_argument_extractor(:parent_child_vector),
          simple_reduction: Core::Compiler::RegistryArgumentBuilder.build_argument_extractor(:simple_reduction)
        }
      end

      def compile_declaration(name, declaration)
        metadata = @metadata[name]

        puts "DEBUG: Compiling #{name}" if ENV["DEBUG_COMPILER"]
        puts "DEBUG: Metadata: #{metadata.inspect}" if ENV["DEBUG_COMPILER"]

        case metadata&.[](:operation_type)
        when :vectorized
          compile_vectorized_operation(declaration.expression, metadata)
        when :reduction
          compile_reduction_operation(declaration.expression, metadata)
        when :array_reference
          compile_array_reference(declaration.expression, metadata)
        when :scalar
          compile_scalar_expression(declaration.expression)
        else
          # Fallback for declarations without metadata (shouldn't happen)
          compile_scalar_expression(declaration.expression)
        end
      end

      def compile_vectorized_operation(expr, metadata)
        strategy = metadata[:strategy]
        registry_call_info = metadata[:registry_call_info]

        puts "DEBUG: Vectorized strategy: #{strategy}" if ENV["DEBUG_COMPILER"]
        puts "DEBUG: Registry call info: #{registry_call_info.inspect}" if ENV["DEBUG_COMPILER"]

        # Get the registry function for this strategy
        registry_fn = Kumi::Registry.fetch(strategy)

        # Pure translation from metadata to registry call
        lambda do |ctx|
          args = build_registry_args(expr, metadata, ctx)
          puts "DEBUG: Calling #{strategy} with args: #{args.map(&:class)}" if ENV["DEBUG_COMPILER"]

          result = registry_fn.call(*args)
          puts "DEBUG: #{strategy} result: #{result.inspect}" if ENV["DEBUG_COMPILER"]
          result
        end
      end

      def build_registry_args(expr, metadata, ctx)
        strategy = metadata[:strategy]
        operands = metadata[:operands] || []

        # Use composed argument extractor
        arg_extractor = @arg_extractors[strategy]
        arg_extractor.call(expr, operands, ctx, @bindings, @accessors)
      end

      def compile_reduction_operation(_expr, metadata)
        puts "DEBUG: Reduction metadata: #{metadata.inspect}" if ENV["DEBUG_COMPILER"]

        # Convert reduction metadata to format expected by RegistryArgumentBuilder
        # Add flattening info to the operand so the extractor can handle it
        operand_with_flattening = metadata[:input_source].dup
        operand_with_flattening[:requires_flattening] = metadata[:requires_flattening]

        operands = [operand_with_flattening]

        # Use composed argument extractor for pure lambda generation
        arg_extractor = @arg_extractors[:simple_reduction]

        lambda do |ctx|
          # Build a dummy expr object with fn_name for the extractor
          # This is needed because the reduction_function extractor expects expr.fn_name
          dummy_expr = OpenStruct.new(fn_name: metadata[:function])
          args = arg_extractor.call(dummy_expr, operands, ctx, @bindings, @accessors)
          puts "DEBUG: Reduction calling with args: #{args.map(&:class)}" if ENV["DEBUG_COMPILER"]

          # Apply reduction: args[0] is the reduce function, args[1] is the input data
          reduce_fn, input_data = args
          result = reduce_fn.call(input_data)

          puts "DEBUG: Reduction result: #{result.inspect}" if ENV["DEBUG_COMPILER"]
          result
        end
      end

      def compile_array_reference(_expr, metadata)
        array_source = metadata[:array_source]

        lambda do |ctx|
          base_ctx = ctx.respond_to?(:ctx) ? ctx.ctx : ctx

          # Array references should use element accessors for field extraction
          raise "Array reference without path: #{array_source}" unless array_source[:path]

          path_key = array_source[:path].join(".")
          element_accessor_key = "#{path_key}:element"

          unless @accessors.key?(element_accessor_key)
            raise "Missing accessor for #{path_key}:element - accessor system should have created this"
          end

          @accessors[element_accessor_key].call(base_ctx)
        end
      end

      def compile_scalar_expression(expr)
        # Use ExpressionBuilder for pure expression compilation
        expression_builder.compile(expr)
      end

      def expression_builder
        @expression_builder ||= Core::Compiler::ExpressionBuilder.new(@bindings)
      end
    end
  end
end
